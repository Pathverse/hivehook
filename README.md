# HiveHook

A simple wrapper around [Hive CE](https://pub.dev/packages/hive_ce) with hook-based middleware.

## Quick Start

```dart
import 'package:hivehook/hivehook.dart';

void main() async {
  // 1. Register & initialize
  HHiveCore.register(HiveConfig(env: 'myapp'));
  await HHiveCore.initialize();

  // 2. Create instance
  final hive = await HHive.create('myapp');

  // 3. Use it
  await hive.put('user', {'name': 'John'});
  final user = await hive.get('user');
  await hive.delete('user');
}
```

## Core API

```dart
await hive.put('key', value);              // Store
await hive.get('key');                     // Retrieve  
await hive.delete('key');                  // Delete
await hive.clear();                        // Clear all

// Cache-aside pattern
final data = await hive.ifNotCached('key', () async => fetchData());

// With metadata
await hive.put('key', value, meta: {'ttl': 300});
final record = await hive.getWithMeta('key');  // {value, meta}
```

## Adding Hooks

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'orders',
  hooks: [
    HiHook(
      uid: 'logger',
      events: ['put', 'get'],
      handler: (payload, ctx) {
        print('[${payload.event}] ${payload.key}');
        return const HiContinue();
      },
    ),
  ],
));
```

## Environment Isolation

Multiple environments stay isolated even when sharing storage:

```dart
HHiveCore.register(HiveConfig(env: 'v1', boxName: 'data'));
HHiveCore.register(HiveConfig(env: 'v2', boxName: 'data'));
await HHiveCore.initialize();

final v1 = await HHive.create('v1');
final v2 = await HHive.create('v2');

await v1.put('key', 'a');  // Only visible to v1
await v2.put('key', 'b');  // Only visible to v2
```

## Installation

```yaml
dependencies:
  hivehook: ^1.0.0-alpha.1
  hive_ce: ^2.19.1
```

## Learn More

- [API Documentation](https://pub.dev/documentation/hivehook/latest/)
- [hihook](https://pub.dev/packages/hihook) - Hook engine
- [Hive CE](https://pub.dev/packages/hive_ce) - Storage backend

## License

MIT
