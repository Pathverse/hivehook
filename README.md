# HiveHook

A powerful plugin system for [Hive](https://pub.dev/packages/hive_ce) that adds hooks, lifecycle management, and middleware capabilities to your NoSQL database operations.

## Why HiveHook?

Centralize cross-cutting concerns like validation, logging, caching, and encryption with a clean, composable hook system instead of scattering logic throughout your database code.

## Quick Start

```dart
import 'package:hivehook/hivehook.dart';

await HHiveCore.initialize();

final config = HHConfig(env: 'myapp', usesMeta: true);
final hive = HHive(config: config.finalize());

await hive.put('user', 'John');
final user = await hive.get('user');
```

## Common Use Cases

### Automatic Data Expiration (TTL)

```dart
import 'package:hivehook/hivehook.dart';

final ttlPlugin = createTTLPlugin(defaultTTLSeconds: 3600); // 1 hour

final config = HHConfig(env: 'cache', usesMeta: true);
config.installPlugin(ttlPlugin);
final hive = HHive(config: config.finalize());

await hive.put('session', sessionData); // Expires after 1 hour
await hive.put('token', jwt, meta: {'ttl': '300'}); // Custom 5-min TTL
```

### LRU Cache

```dart
import 'package:hivehook/hivehook.dart';

final lruPlugin = createLRUPlugin(maxSize: 100);

final config = HHConfig(env: 'cache', usesMeta: true);
config.installPlugin(lruPlugin);
final hive = HHive(config: config.finalize());

// Automatically evicts least recently used items when full
await hive.put('data1', value1);
```

### Validation

```dart
final config = HHConfig(
  env: 'users',
  usesMeta: true,
  actionHooks: [
    HActionHook(
      latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
      action: (ctx) async {
        if (ctx.payload.value == null || ctx.payload.value.isEmpty) {
          throw ArgumentError('Value cannot be empty');
        }
      },
    ),
  ],
);
```

### Audit Logging

```dart
final auditLog = <String>[];

final config = HHConfig(
  env: 'production',
  usesMeta: true,
  actionHooks: [
    HActionHook(
      latches: [HHLatch(triggerType: TriggerType.valueWrite, isPost: true)],
      action: (ctx) async {
        auditLog.add('Written: ${ctx.payload.key} at ${DateTime.now()}');
      },
    ),
  ],
);
```

### Data Encryption

```dart
final config = HHConfig(
  env: 'secure',
  usesMeta: true,
  serializationHooks: [
    SerializationHook(
      serialize: (ctx) async => encrypt(ctx.payload.value),
      deserialize: (ctx) async => decrypt(ctx.payload.value),
    ),
  ],
);
```

### JSON Transformation

```dart
final config = HHConfig(
  env: 'api',
  usesMeta: true,
  serializationHooks: [
    SerializationHook(
      serialize: (ctx) async => jsonEncode(ctx.payload.value),
      deserialize: (ctx) async => jsonDecode(ctx.payload.value),
    ),
  ],
);

await hive.put('user', {'name': 'John', 'age': 30});
final user = await hive.get('user'); // Returns Map
```

## Creating Custom Plugins

```dart
import 'package:hivehook/hivehook.dart';

HHPlugin createCompressionPlugin() {
  return HHPlugin(
    serializationHooks: [
      SerializationHook(
        serialize: (ctx) async => compress(ctx.payload.value),
        deserialize: (ctx) async => decompress(ctx.payload.value),
      ),
    ],
  );
}

// Use it
final config = HHConfig(env: 'app', usesMeta: true);
config.installPlugin(createCompressionPlugin());

// Remove it later
config.uninstallPlugin(plugin.uid);
```

## Combining Plugins

```dart
final config = HHConfig(env: 'cache', usesMeta: true);

config.installPlugin(createTTLPlugin(defaultTTLSeconds: 300));
config.installPlugin(createLRUPlugin(maxSize: 50));
config.installPlugin(createCompressionPlugin());

final hive = HHive(config: config.finalize());

// All plugins work together automatically
await hive.put('data', largeObject);
// → Compressed, TTL tracked, LRU managed
```

## Hook Types

**Action Hooks** - Execute logic before/after operations:
```dart
HActionHook(
  latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
  action: (ctx) async { /* your logic */ },
)
```

**Serialization Hooks** - Transform data:
```dart
SerializationHook(
  serialize: (ctx) async => transform(ctx.payload.value),
  deserialize: (ctx) async => reverseTransform(ctx.payload.value),
)
```

## Trigger Types

- `valueWrite` - Data write operations
- `valueRead` - Data read operations  
- `onDelete` - Delete operations
- `onPop` - Pop (read + delete) operations
- `onClear` - Clear all operations
- `metadataWrite` / `metadataRead` - Metadata operations

## Control Flow

```dart
// Stop execution and return value
throw HHCtrlException(
  nextPhase: NextPhase.f_break,
  returnValue: null,
);

// Skip remaining hooks
throw HHCtrlException(nextPhase: NextPhase.f_skip);

// Delete key and stop
throw HHCtrlException(nextPhase: NextPhase.f_delete);
```

## Metadata

```dart
// Store additional info
await hive.put('key', 'value', meta: {
  'created_at': DateTime.now().toIso8601String(),
  'author': 'user123',
});

// Read metadata
final meta = await hive.getMeta('key');
```

## Installation

```yaml
dependencies:
  hivehook: ^1.0.0
  hive_ce: ^2.0.0
```

```dart
import 'package:hivehook/hivehook.dart';

void main() async {
  await HHiveCore.initialize();
  // Use HiveHook
}
```

## Documentation

- [Plugin Flow Guide](docs/plugin_flow.md) - How plugins work internally
- Template Plugins:
  - [TTL Plugin](lib/templates/ttl_plugin.dart) - Time-based expiration
  - [LRU Plugin](lib/templates/lru_plugin.dart) - Size-limited cache

## Features

✅ Hook system for intercepting operations  
✅ Plugin architecture for reusable logic  
✅ Metadata support for additional context  
✅ Control flow management  
✅ Type-safe API  
✅ Comprehensive test coverage  

## When to Use

**Use HiveHook for:**
- Automatic data expiration
- Size-limited caches
- Data validation
- Encryption/decryption
- Audit logging
- Data transformation
- Rate limiting
- Any cross-cutting concerns

**Use plain Hive for:**
- Simple key-value storage
- No middleware needed
- Maximum performance critical

## License

MIT
