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

## Features

- 🔌 **Hook-based middleware** - Transform, validate, or intercept operations
- 🔒 **Meta hooks** - Separate pipeline for metadata (encryption, TTL, audit)
- 🏠 **Environment isolation** - Multiple envs share storage safely
- ⚡ **Meta-first pattern** - Efficient TTL checks before value decryption
- 📦 **Lazy initialization** - BoxCollections open on first access

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

// Standalone meta operations
final meta = await hive.getMeta('key');
await hive.putMeta('key', {'views': 100});
await hive.deleteMeta('key');
```

## Adding Hooks

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'orders',
  hooks: [
    HiHook(
      uid: 'logger',
      events: ['read', 'write'],
      handler: (payload, ctx) {
        print('${payload.key}: ${payload.value}');
        return const HiContinue();
      },
    ),
  ],
));
```

## Meta Hooks

Separate hook pipeline for metadata operations:

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'secure',
  withMeta: true,
  metaHooks: [
    // Encrypt metadata on write
    HiHook(
      uid: 'meta_encrypt',
      events: ['writeMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        if (meta != null) {
          final encrypted = encryptMeta(meta);
          return HiContinue(payload: payload.copyWith(value: encrypted));
        }
        return const HiContinue();
      },
    ),
    // TTL check (meta-first pattern)
    HiHook(
      uid: 'ttl_check',
      events: ['readMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        if (isExpired(meta)) {
          return HiBreak(returnValue: null); // Skip value read
        }
        return const HiContinue();
      },
    ),
  ],
));
```

**Events:** `readMeta`, `writeMeta`, `deleteMeta`, `clearMeta`

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
