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

## Folder Structure

```
lib/
├── hivehook.dart           # Barrel export
└── src/
    ├── hhive.dart          # Facade, owns engine
    ├── core/
    │   ├── hive_config.dart  # HiveConfig with boxName
    │   └── hive_core.dart    # Static manager
    └── store/
        └── hbox_store.dart   # {env}:: key prefixing
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
