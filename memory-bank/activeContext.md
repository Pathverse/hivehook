# Active Context

## Current Status (Feb 2, 2026)

### ✅ 125 Tests Passing

Core implementation complete with env isolation, lazy BoxCollection opening, and **meta hooks**.

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
- [ ] TTL/LRU plugin integration
- [ ] Web debug support
- [ ] HiveBoxType.box implementation
