# HiveHook

A minimal [Hive CE](https://pub.dev/packages/hive_ce) storage adapter with hook-based lifecycle management via [hihook](https://pub.dev/packages/hihook).

## Quick Start

```dart
import 'package:hivehook/hivehook.dart';

void main() async {
  // 1. Register environment
  HHiveCore.register(HiveConfig(
    env: 'myapp',
    withMeta: true,
  ));

  // 2. Initialize
  await HHiveCore.initialize();

  // 3. Create facade
  final hive = await HHive.create('myapp');

  // 4. CRUD operations
  await hive.put('user', {'name': 'John'});
  final user = await hive.get('user'); // {'name': 'John'}
  await hive.delete('user');
}
```

## Architecture

```
User Code → HHive (facade) → HiEngine (hooks) → HBoxStore (pure) → Hive CE
```

- **HHive** - User-facing facade that emits events to hihook
- **HHiveCore** - Centralized Hive initialization & lifecycle
- **HBoxStore** - Pure HiStore implementation (no hook logic)
- **HiveConfig** - Configuration for environments

## Environment Isolation

Multiple environments can share the same physical box while remaining isolated:

```dart
// Register multiple envs sharing one box
HHiveCore.register(HiveConfig(env: 'users_v1', boxName: 'users'));
HHiveCore.register(HiveConfig(env: 'users_v2', boxName: 'users'));
await HHiveCore.initialize();

final v1 = await HHive.create('users_v1');
final v2 = await HHive.create('users_v2');

await v1.put('alice', {'role': 'admin'});  // Stored as users_v1::alice
await v2.put('alice', {'role': 'guest'});  // Stored as users_v2::alice

// Each env sees only its own keys
```

## Hooks

Hooks use the hihook `HiHook` pattern with events and handlers:

### Value Transformation

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'orders',
  hooks: [
    HiHook(
      uid: 'tax_calculator',
      events: ['put'],
      handler: (payload, ctx) {
        final value = payload.value as Map<String, dynamic>?;
        if (value != null && value.containsKey('amount')) {
          final amount = value['amount'] as num;
          final transformed = Map<String, dynamic>.from(value);
          transformed['tax'] = (amount * 0.1).toDouble();
          transformed['total'] = (amount * 1.1).toDouble();
          return HiContinue(payload: payload.copyWith(value: transformed));
        }
        return const HiContinue();
      },
    ),
  ],
));

await hive.put('order', {'item': 'Widget', 'amount': 100.0});
// Stored with tax: 10.0, total: 110.0
```

### Validation

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'users',
  hooks: [
    HiHook(
      uid: 'email_validator',
      events: ['put'],
      handler: (payload, ctx) {
        final value = payload.value as Map<String, dynamic>?;
        if (value != null) {
          final email = value['email'] as String?;
          if (email == null || !email.contains('@')) {
            return HiBreak(returnValue: {'error': 'Invalid email'});
          }
        }
        return const HiContinue();
      },
    ),
  ],
));

await hive.put('user:1', {'email': 'invalid'}); // Blocked by hook
await hive.put('user:2', {'email': 'a@b.com'}); // Stored successfully
```

### Logging

```dart
HiHook(
  uid: 'logger',
  events: ['put', 'get', 'delete'],
  handler: (payload, ctx) {
    print('[${payload.event}] key=${payload.key}');
    return const HiContinue();
  },
)
```

## API Reference

### Core Methods

```dart
await hive.put('key', value);            // Store value
await hive.get('key');                   // Retrieve value
await hive.delete('key');                // Delete key
await hive.pop('key');                   // Get + delete
await hive.clear();                      // Clear this env's keys

// With metadata
await hive.put('key', value, meta: {'ttl': 300});
await hive.getWithMeta('key');           // Get value + metadata
await hive.getMeta('key');               // Get metadata only
await hive.setMeta('key', {'custom': 1}); // Update metadata

// Iteration
await for (final key in hive.keys()) { ... }
```

### HiveConfig Options

| Option | Description |
|--------|-------------|
| `env` | Unique environment ID (required) |
| `boxName` | Physical box name (default: env) |
| `boxCollectionName` | BoxCollection name (default: 'hivehooks') |
| `hooks` | List of HiHook to apply |
| `withMeta` | Enable metadata storage |
| `storageMode` | `json` (default) or `native` |
| `typeAdapters` | TypeAdapters for native mode |
| `jsonEncoder` | Custom JSON encoder |
| `jsonDecoder` | Custom JSON decoder |

### Hook Events

| Event | When |
|-------|------|
| `put` | Before/after `put()` |
| `get` | Before/after `get()` |
| `delete` | Before/after `delete()` |
| `pop` | Before/after `pop()` |
| `clear` | Before/after `clear()` |

### Hook Results

| Result | Behavior |
|--------|----------|
| `HiContinue()` | Continue to next hook / storage |
| `HiContinue(payload: ...)` | Continue with modified payload |
| `HiBreak(returnValue: ...)` | Stop pipeline, return value |

## Installation

```yaml
dependencies:
  hivehook: ^1.0.0-alpha.1
  hive_ce: ^2.19.1
```

See [hive_ce on pub.dev](https://pub.dev/packages/hive_ce) for Hive documentation.

## License

MIT
