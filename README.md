# HiveHook

Add validation, caching, encryption, and logging to [Hive](https://pub.dev/packages/hive_ce) with zero boilerplate.

## Quick Start

```dart
import 'package:hivehook/hivehook.dart';

void main() async {
  // 1. Initialize
  final config = HHConfig(env: 'myapp');
  await HHiveCore.initialize();
  
  // 2. Use like normal Hive
  final hive = HHive(config: config.finalize());
  await hive.put('user', 'John');
  final user = await hive.get('user'); // 'John'
}
```

## Common Use Cases

### Auto-Expiring Cache (TTL)

```dart
final config = HHConfig(env: 'cache');
config.installPlugin(createTTLPlugin(defaultTTLSeconds: 3600)); // 1 hour
final hive = HHive(config: config.finalize());

await hive.put('session', data);              // Expires in 1 hour
await hive.put('token', jwt, meta: {'ttl': 300}); // Custom 5-min TTL
```

### Size-Limited Cache (LRU)

```dart
final config = HHConfig(env: 'cache');
config.installPlugin(createLRUPlugin(maxSize: 100));
final hive = HHive(config: config.finalize());

// Automatically evicts oldest items when cache exceeds 100 entries
await hive.put('item', value);
```

### Validation

```dart
final config = HHConfig(
  env: 'users',
  actionHooks: [
    HActionHook(
      latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
      action: (ctx) async {
        if (ctx.payload.value == null) {
          throw ArgumentError('Value cannot be null');
        }
      },
    ),
  ],
);
```

### Encryption

```dart
final config = HHConfig(
  env: 'secure',
  serializationHooks: [
    SerializationHook(
      id: 'aes',
      serialize: (ctx) async => encrypt(ctx.payload.value),
      deserialize: (ctx) async => decrypt(ctx.payload.value),
    ),
  ],
);
```

### Combine Multiple Plugins

```dart
final config = HHConfig(env: 'cache');
config.installPlugin(createTTLPlugin(defaultTTLSeconds: 300));
config.installPlugin(createLRUPlugin(maxSize: 50));
final hive = HHive(config: config.finalize());

// Both TTL expiration AND LRU eviction active
await hive.put('data', value);
```

## API Reference

### Core Methods

```dart
await hive.put('key', value);           // Store value
await hive.get('key');                   // Retrieve value
await hive.delete('key');                // Delete key
await hive.pop('key');                   // Get + delete
await hive.clear();                      // Clear all

// With metadata
await hive.put('key', value, meta: {'ttl': 300});
await hive.getMeta('key');               // Get metadata only
await hive.setMeta('key', {'custom': 1}); // Update metadata
```

### Hook Triggers

| Trigger | When |
|---------|------|
| `valueWrite` | Before/after `put()` |
| `valueRead` | Before/after `get()` |
| `onDelete` | Before/after `delete()` |
| `onPop` | Before/after `pop()` |
| `onClear` | Before/after `clear()` |

## Web Debug Mode

When `HHiveCore.DEBUG_OBJ` is enabled (auto-detected via `kDebugMode`), original objects are stored to `window.hiveDebug` for easy inspection in browser DevTools:

```js
// In browser console:
window.hiveDebug                    // View all stored objects
window.hiveDebug['myEnv::myKey']    // View specific key
Object.keys(window.hiveDebug)       // List all keys
```

> **Note**: Debug storage only works on web platform.

## Installation

```yaml
dependencies:
  hivehook: ^0.2.0
  hive_ce: ^2.10.0
```

See [hive_ce on pub.dev](https://pub.dev/packages/hive_ce) for Hive documentation.

## License

MIT
