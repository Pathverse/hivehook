# Active Context

## Current Status (Jan 29, 2026)

### ✅ 112 Tests Passing

Core implementation complete with env isolation + lazy BoxCollection opening.

## Architecture

```
User → HHive → HiEngine → HBoxStore → Hive CE
                              ↓
                        Keys: {env}::{key}
                        Box: {boxName}
```

## Recent: Env Isolation Feature

| Feature | Behavior |
|---------|----------|
| Unique env | `register()` throws on duplicate |
| boxName | Defaults to env, allows sharing |
| Key storage | `{env}::{key}` in `{boxName}` |
| API | Transparent (user sees plain keys) |
| clear() | Only clears this env's keys |

## HiveConfig Structure

```dart
class HiveConfig {
  final String env;              // Unique ID (required)
  final String boxName;          // Physical box (default: env)
  final List<HiHook> hooks;
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

- [ ] TTL/LRU plugin integration
- [ ] Web debug support
- [ ] HiveBoxType.box implementation
- [ ] Example app migration
