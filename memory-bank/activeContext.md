# Encryption Support (hive_ce)

Up to the most recent hive_ce version (2.19.3 and current), BoxCollection on web still does **not** support built-in encryption (HiveCipher is ignored). Regular boxes on web **do** support encryption. Application-level encryption via meta hooks is the only cross-platform solution for BoxCollection.

# Active Context

## Current Status (Feb 8, 2026)

### ✅ 145 Tests Passing

Core implementation complete with env isolation, lazy BoxCollection opening, **meta hooks**, **path parameter**, **test isolation**, and **BoxCollectionConfig**.

## Recent: BoxCollectionConfig (2026-02-08)

Added per-collection configuration separate from HiveConfig:

```dart
// Pre-configure collection (optional)
HHiveCore.registerCollection(BoxCollectionConfig(
  name: 'myapp',
  path: '/custom/path',
  cipher: myCipher,
  includeMeta: true,  // null=auto, true=force, false=forbid
));

// HiveConfig references collection
HHiveCore.register(HiveConfig(env: 'users', boxCollectionName: 'myapp'));
```

**Changes:**
- New `BoxCollectionConfig` class with path, cipher, boxNames, includeMeta
- `HHiveCore.registerCollection()` for explicit collection config
- `register()` auto-creates BoxCollectionConfig if not pre-registered
- Collection config path/cipher takes precedence over globals
- 20 new tests (14 unit + 6 integration)

## Recent: README Conventions Documented (2026-02-02)

Rewrote README.md following pub.dev package conventions (slang reference). Documented rules in systemPatterns.md:
- Self-contained documentation (inline code, not demo app showcases)
- Structure: About → Getting Started → API → Features → Configuration
- No license text in README body (separate LICENSE file)

## Recent: Test File Isolation (2026-02-02)

Fixed test pollution - Hive collection files were being created in project directory instead of temp:

**Changes:**
- Added `initWithTempPath()` helper for tests that register configs manually
- Updated all direct `HHiveCore.initialize()` calls in tests to use helpers
- Tests now use `Directory.systemTemp.path` for Hive storage
- `_effectiveInitPath` stored in `HHiveCore` and used by `BoxCollection.open()`

**Test helpers:**
```dart
// For tests that need custom registration before init
await initWithTempPath();

// For simple tests with configs
await initHiveCore(configs: [...]);

// For single-env tests
final hive = await createTestHive();
```

## Recent: Path Parameter for initialize() (2026-02-02)

Added optional `path` parameter to `HHiveCore.initialize()` for non-web platforms:

```dart
// Option 1: Pass path directly
await HHiveCore.initialize(path: '/my/storage/path');

// Option 2: Set static field (existing behavior)
HHiveCore.HIVE_INIT_PATH = '/my/storage/path';
await HHiveCore.initialize();

// Option 3: No path for web
await HHiveCore.initialize();
```

## Recent: Meta Hooks Implementation (2026-02-02)

Added separate hook pipeline for metadata operations:

**New Features:**
- `metaHooks` parameter in HiveConfig for metadata-specific hooks
- `metaEngine` in HHive for separate meta hook execution
- New events: `readMeta`, `writeMeta`, `deleteMeta`, `clearMeta`
- Standalone methods: `getMeta()`, `putMeta()`, `deleteMeta()`
- **Meta-first pattern**: `readMeta` fires BEFORE `read` for TTL/invalidation checks

**Use Cases:**
- Encrypt/decrypt metadata separately from values
- TTL checks without decrypting value (efficiency)
- Audit trails for metadata operations
- Update metadata without touching value

**Example:**
```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'secure',
  withMeta: true,
  metaHooks: [
    HiHook(
      uid: 'meta_encryptor',
      events: ['writeMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        // Transform meta...
        return HiContinue(payload: payload.copyWith(value: encrypted));
      },
    ),
  ],
));
```

## Architecture

```
User → HHive → HiEngine → HBoxStore → Hive CE
                              ↓
                        Keys: {env}::{key}
                        Box: {boxName}
```

## HiveConfig Structure

```dart
class HiveConfig {
  final String env;              // Unique ID (required)
  final String boxName;          // Physical box (default: env)
  final List<HiHook> hooks;      // Value hooks
  final List<HiHook> metaHooks;  // Metadata hooks (NEW)
  final HiveBoxType type;
  final bool withMeta;
  final String boxCollectionName;
  final HiveStorageMode storageMode;
  final List<TypeAdapter> typeAdapters;
  final HiveJsonEncoder? jsonEncoder;
  final HiveJsonDecoder? jsonDecoder;
}
```

## Usage Example

```dart
// Envs sharing a box (isolated by prefix)
HHiveCore.register(HiveConfig(env: 'v1', boxName: 'data'));
HHiveCore.register(HiveConfig(env: 'v2', boxName: 'data'));
await HHiveCore.initialize();

final h1 = await HHive.create('v1');
final h2 = await HHive.create('v2');

await h1.put('key', 'a');  // Stored as v1::key
await h2.put('key', 'b');  // Stored as v2::key
// Each sees only its own keys
```

## Recent: Lazy BoxCollection Opening

| Rule | Behavior |
|------|----------|
| Opened collection | Cannot register new boxes (throws) |
| Unopened collection | Opens lazily on first `getStore()` |
| `HiveBoxType.box` | Can register anytime (future) |

**Key additions:**
- `_openedCollectionNames` - Set tracking locked collections
- `isCollectionOpened(name)` - Public check method
- `_openBoxCollection()` - Lazy opening helper

## Next Steps

- [x] Meta hooks implementation
- [x] Example app with meta hooks demo
- [x] Test file cleanup automation
- [x] Path parameter for initialize()
- [x] Test isolation (temp directory)
- [ ] TTL/LRU plugin integration
- [ ] Web debug support
- [ ] HiveBoxType.box implementation
