# System Patterns

## Architecture

```
┌─────────────────────────────────────────────────┐
│                User Application                  │
│  hive.put('key', value) / hive.get('key')       │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│  HHive (Facade)                                  │
│   ├── Owns HiEngine (value hooks)               │
│   ├── Owns metaEngine (meta hooks)              │
│   ├── Value events: read, write, delete, clear  │
│   └── Meta events: readMeta, writeMeta,         │
│                    deleteMeta, clearMeta        │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│  HHiveCore (Static Manager)                      │
│   ├── registerCollection() - collection config  │
│   ├── register() - unique env, checks opened    │
│   ├── initialize() - opens registered boxes     │
│   ├── getStore() - lazy opens if needed         │
│   ├── isCollectionOpened(name) - check locked   │
│   └── getHooksFor(env) → [global + config]      │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│  HBoxStore (Pure Storage)                        │
│   ├── Keys: {env}::{key} in {boxName} box       │
│   ├── Meta: {env}::{key} in _meta box           │
│   └── Transparent: users see plain keys         │
└─────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│  Hive CE (BoxCollection)                         │
│   ├── Data box: {boxName}                       │
│   └── Meta box: _meta (shared, namespaced)      │
└─────────────────────────────────────────────────┘
```

## Key Isolation Pattern

```dart
// Multiple envs can share same physical box
HiveConfig(env: 'users_v1', boxName: 'users')
HiveConfig(env: 'users_v2', boxName: 'users')

// Storage layout:
// Box "users":
//   users_v1::alice → {...}
//   users_v1::bob → {...}
//   users_v2::alice → {...}  // Different env, no collision
```

## BoxCollectionConfig Pattern

Per-collection configuration separate from HiveConfig:

```dart
// Pre-configure collection (optional)
HHiveCore.registerCollection(BoxCollectionConfig(
  name: 'myapp',
  storagePath: '/custom/path',    // Per-collection path
  encryptionCipher: myCipher,     // Per-collection encryption
  includeMeta: true,              // null=auto, true=force, false=forbid
));

// HiveConfig references collection (auto-creates if not pre-registered)
HHiveCore.register(HiveConfig(
  env: 'users',
  boxCollectionName: 'myapp',
));
```

**includeMeta behavior:**
| Value | Behavior |
|-------|----------|
| `null` | Auto-detect from HiveConfig.withMeta |
| `true` | Always include `_meta` box |
| `false` | Never include (error if HiveConfig.withMeta conflicts) |

**Resolution order (per-collection > global):**
| Setting | Resolution |
|---------|------------|
| `storagePath` | BoxCollectionConfig.storagePath ?? HHiveCore.storagePath |
| `encryptionCipher` | BoxCollectionConfig.encryptionCipher ?? HHiveCore.encryptionCipher |

**Registration constraints (opened BoxCollection):**
| Scenario | Behavior |
|----------|----------|
| New box name | Throws StateError |
| Existing box name with new env | Allowed (reuses opened box) |

## Folder Structure

```
lib/
├── hivehook.dart           # Barrel export
└── src/
    ├── hhive.dart          # Facade, owns engine
    ├── core/
    │   ├── box_collection_config.dart  # Per-collection settings
    │   ├── hive_config.dart  # HiveConfig with boxName
    │   └── hive_core.dart    # Static manager
    └── store/
        ├── hbox_store.dart   # {env}:: key prefixing
        └── hive_box_adapter.dart  # Box abstraction
```

## HiveBoxAdapter Pattern

Abstracts box operations for both CollectionBox and regular Box:

```dart
abstract class HiveBoxAdapter<E> {
  Future<E?> get(String key);
  Future<void> put(String key, E value);
  Future<void> delete(String key);
  Future<List<String>> getAllKeys();
  Future<Map<String, E>> getAllValues();
}

// Implementations:
// - CollectionBoxAdapter: wraps CollectionBox
// - RegularBoxAdapter: wraps Box (Hive.openBox)
```

**Usage in HBoxStore:**
```dart
class HBoxStore {
  final HiveBoxAdapter<dynamic> box;      // Works with either
  final HiveBoxAdapter<String>? metaBox;
}
```

## Naming Conventions

| Prefix | Package | Example |
|--------|---------|---------|
| `HH` | hivehook | `HHive`, `HHiveCore` |
| `Hi` | hihook | `HiHook`, `HiEngine`, `HiStore` |
| `Hive` | config | `HiveConfig`, `HiveBoxType` |

## Settings Merge

| Setting | Merge |
|---------|-------|
| `typeAdapters` | Global + config (all) |
| `jsonEncoder` | Config ?? global |
| `hooks` | Global first, then config |

## Storage Modes

- **JSON** (default): `jsonEncode/Decode`, custom via encoder/decoder
- **Native**: Hive TypeAdapters for complex types

## Event Flow

```
# Value operations
hive.put() → engine.emit('write') → hooks → storage
         → metaEngine.emit('writeMeta') → metaHooks → storage

# Meta-first pattern (read)
hive.get() → metaEngine.emit('readMeta') → check TTL/invalidation
          → engine.emit('read') → hooks → return value
```

## Meta Hooks Pattern

For meta hooks, metadata is passed as `payload.value`:
```dart
HiHook(
  events: ['writeMeta'],
  handler: (payload, ctx) {
    final meta = payload.value as Map<String, dynamic>?;
    // Transform meta...
    return HiContinue(payload: payload.copyWith(value: transformed));
  },
)
```

## README Documentation Rules

Package READMEs should be **self-contained documentation**, not demo app showcases.

**Structure (following pub.dev conventions like slang):**

1. **About this library** - Feature bullets + quick usage snippet
2. **Table of Contents** - Navigation links
3. **Getting Started** - Step-by-step: dependencies → init → usage
4. **Core API** - Complete reference with code examples
5. **Feature sections** - Each major feature with inline examples
6. **Configuration** - Options tables with types/defaults
7. **Learn More** - Links to dependencies/related packages

**Rules:**
- Code examples are inline, not references to example app
- Each section teaches usage directly
- Use tables for configuration options
- No "Example App" section as primary content
- No license text in README (LICENSE file exists)
- Example app exists for interactive demos, not as documentation

**Don't:**
- Point to example files as primary documentation
- Make README a tour of the demo app
- Include MIT license text (separate LICENSE file)
