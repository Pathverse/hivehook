# HiveHook

A Hive CE storage adapter with hook-based middleware powered by [hihook](https://pub.dev/packages/hihook).

## About this library

- 🔌 **Hook-based middleware** - Transform, validate, or intercept storage operations
- 🔒 **Meta hooks** - Separate pipeline for metadata (encryption, TTL, audit)
- 🏠 **Environment isolation** - Multiple envs share storage safely via key prefixing
- ⚡ **Meta-first pattern** - Check TTL/permissions before decrypting values
- 📦 **Lazy initialization** - BoxCollections open on first access

This is how you use it:

```dart
final hive = await HHive.create('myapp');

await hive.put('user:1', {'name': 'Alice', 'role': 'admin'});
final user = await hive.get('user:1');
await hive.delete('user:1');

// With metadata
await hive.put('session', token, meta: {'expiresAt': timestamp});
final record = await hive.getWithMeta('session');
print(record.value);  // token
print(record.meta);   // {expiresAt: ...}
```

## Table of Contents

- [Getting Started](#getting-started)
- [Core API](#core-api)
- [Hooks](#hooks)
  - [Value Hooks](#value-hooks)
  - [Meta Hooks](#meta-hooks)
  - [Hook Results](#hook-results)
- [Advanced Features](#advanced-features)
  - [Environment Isolation](#environment-isolation)
  - [TTL & Caching](#ttl--caching)
  - [Metadata Encryption](#metadata-encryption)
- [Configuration](#configuration)
- [License](#license)

## Getting Started

**Step 1: Add dependencies**

```yaml
dependencies:
  hivehook: ^1.0.0-alpha.1
  hive_ce: ^2.19.1
```

**Step 2: Register and initialize**

```dart
import 'package:hivehook/hivehook.dart';

void main() async {
  // Register environment(s)
  HHiveCore.register(HiveConfig(
    env: 'myapp',
    withMeta: true,  // Enable metadata storage
  ));

  // Initialize Hive
  await HHiveCore.initialize();

  // Create instance and use
  final hive = await HHive.create('myapp');
  await hive.put('key', 'value');
}
```

**Step 3: Use it**

```dart
// Basic CRUD
await hive.put('users/1', {'name': 'Alice'});
final user = await hive.get('users/1');
await hive.delete('users/1');
await hive.clear();

// With metadata
await hive.put('config', data, meta: {'version': 2});
final record = await hive.getWithMeta('config');

// Cache-aside pattern
final data = await hive.ifNotCached('expensive', () async {
  return await fetchFromApi();
});
```

## Core API

### Basic Operations

```dart
await hive.put(key, value);           // Store value
await hive.get(key);                  // Retrieve value
await hive.delete(key);               // Delete entry
await hive.clear();                   // Clear all entries in this env
```

### Metadata Operations

```dart
// Store with metadata
await hive.put('key', value, meta: {'ttl': 300, 'source': 'api'});

// Retrieve value + metadata together
final record = await hive.getWithMeta('key');
print(record.value);  // the value
print(record.meta);   // {ttl: 300, source: 'api'}

// Standalone metadata operations
final meta = await hive.getMeta('key');
await hive.putMeta('key', {'views': 100});
await hive.deleteMeta('key');
```

### Cache-Aside Pattern

```dart
// Only calls factory if key doesn't exist
final data = await hive.ifNotCached('users/list', () async {
  return await api.fetchUsers();
});
```

## Hooks

Hooks intercept storage operations to transform, validate, or log data.

### Value Hooks

Value hooks handle the main data operations: `read`, `write`, `delete`, `clear`.

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'orders',
  hooks: [
    // Auto-calculate totals on write
    HiHook(
      uid: 'tax_calculator',
      events: ['write'],
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

await hive.put('order/1', {'amount': 100.0});
final order = await hive.get('order/1');
// order = {amount: 100.0, tax: 10.0, total: 110.0}
```

### Meta Hooks

Meta hooks handle metadata operations: `readMeta`, `writeMeta`, `deleteMeta`, `clearMeta`.

They run in a separate pipeline, enabling patterns like:
- Encrypt/decrypt sensitive metadata
- Check TTL before reading the value (meta-first pattern)
- Audit trail for metadata access

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'secure',
  withMeta: true,
  metaHooks: [
    // Encrypt API keys in metadata
    HiHook(
      uid: 'meta_encryptor',
      events: ['writeMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        if (meta != null && meta.containsKey('apiKey')) {
          final encrypted = Map<String, dynamic>.from(meta);
          encrypted['apiKey'] = base64Encode(utf8.encode(meta['apiKey']));
          encrypted['_encrypted'] = true;
          return HiContinue(payload: payload.copyWith(value: encrypted));
        }
        return const HiContinue();
      },
    ),
    // Decrypt on read
    HiHook(
      uid: 'meta_decryptor',
      events: ['readMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        if (meta?['_encrypted'] == true) {
          final decrypted = Map<String, dynamic>.from(meta!);
          decrypted['apiKey'] = utf8.decode(base64Decode(meta['apiKey']));
          decrypted.remove('_encrypted');
          return HiContinue(payload: payload.copyWith(value: decrypted));
        }
        return const HiContinue();
      },
    ),
  ],
));
```

### Hook Results

Hooks return one of two results:

| Result | Effect |
|--------|--------|
| `HiContinue()` | Proceed to next hook (optionally with modified payload) |
| `HiBreak(returnValue)` | Stop pipeline immediately and return value |

**Validation example using HiBreak:**

```dart
HiHook(
  uid: 'validator',
  events: ['write'],
  handler: (payload, ctx) {
    final value = payload.value as Map<String, dynamic>?;
    final email = value?['email'] as String?;
    if (email != null && !email.contains('@')) {
      // Block the write operation
      return HiBreak(returnValue: null);
    }
    return const HiContinue();
  },
)
```

### Hook Priority

Hooks execute in priority order (higher first):

```dart
hooks: [
  HiHook(uid: 'first', priority: 100, ...),   // Runs first
  HiHook(uid: 'second', priority: 50, ...),   // Runs second
  HiHook(uid: 'third', priority: 10, ...),    // Runs third
]
```

## Advanced Features

### Environment Isolation

Multiple environments can share the same storage file while remaining completely isolated. Keys are prefixed internally with `{env}::`.

```dart
// Register multiple environments
HHiveCore.register(HiveConfig(env: 'v1', boxName: 'data'));
HHiveCore.register(HiveConfig(env: 'v2', boxName: 'data'));
await HHiveCore.initialize();

final v1 = await HHive.create('v1');
final v2 = await HHive.create('v2');

await v1.put('config', 'old');  // Stored as 'v1::config'
await v2.put('config', 'new');  // Stored as 'v2::config'

print(await v1.get('config'));  // 'old'
print(await v2.get('config'));  // 'new'

await v1.clear();  // Only clears v1 keys, v2 unaffected
```

### TTL & Caching

Implement time-to-live with metadata:

```dart
// Store with TTL
Future<void> putWithTtl(String key, dynamic value, int ttlSeconds) async {
  await hive.put(key, value, meta: {
    'createdAt': DateTime.now().millisecondsSinceEpoch,
    'ttlSeconds': ttlSeconds,
  });
}

// Check if expired
Future<T?> getIfValid<T>(String key) async {
  final record = await hive.getWithMeta(key);
  if (record.value == null || record.meta == null) return null;
  
  final createdAt = record.meta!['createdAt'] as int;
  final ttl = record.meta!['ttlSeconds'] as int;
  final elapsed = DateTime.now().millisecondsSinceEpoch - createdAt;
  
  if (elapsed > ttl * 1000) {
    await hive.delete(key);  // Clean up expired
    return null;
  }
  return record.value as T;
}

// Cache-aside with TTL
Future<T> getCachedOrFetch<T>(
  String key,
  Future<T> Function() fetcher, {
  int ttlSeconds = 60,
}) async {
  final cached = await getIfValid<T>(key);
  if (cached != null) return cached;
  
  final fresh = await fetcher();
  await putWithTtl(key, fresh, ttlSeconds);
  return fresh;
}
```

### Metadata Encryption

Use meta hooks for transparent encryption:

```dart
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'secure',
  withMeta: true,
  metaHooks: [
    HiHook(
      uid: 'encrypt',
      events: ['writeMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        if (meta == null) return const HiContinue();
        
        final encrypted = yourEncryptFunction(jsonEncode(meta));
        return HiContinue(
          payload: payload.copyWith(value: {'_e': encrypted}),
        );
      },
    ),
    HiHook(
      uid: 'decrypt',
      events: ['readMeta'],
      handler: (payload, ctx) {
        final meta = payload.value as Map<String, dynamic>?;
        if (meta == null || !meta.containsKey('_e')) {
          return const HiContinue();
        }
        
        final decrypted = jsonDecode(yourDecryptFunction(meta['_e']));
        return HiContinue(
          payload: payload.copyWith(value: decrypted),
        );
      },
    ),
  ],
));
```

## Configuration

### HiveConfig Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `env` | `String` | required | Unique environment identifier |
| `boxName` | `String?` | `env` | Physical box name (allows sharing) |
| `boxCollectionName` | `String` | `'hivehooks'` | BoxCollection name |
| `type` | `HiveBoxType` | `boxCollection` | Storage type (see below) |
| `withMeta` | `bool` | `true` | Enable metadata storage |
| `hooks` | `List<HiHook>` | `[]` | Value operation hooks |
| `metaHooks` | `List<HiHook>` | `[]` | Metadata operation hooks |

### Storage Types

| Type | Description |
|------|-------------|
| `HiveBoxType.boxCollection` | Uses BoxCollection (default). All boxes must be registered before `initialize()`. |
| `HiveBoxType.box` | Uses individual Box. Opens lazily, ideal for dynamic scenarios. |

```dart
// BoxCollection (default) - register all before init
HHiveCore.register(HiveConfig(env: 'users'));
HHiveCore.register(HiveConfig(env: 'orders'));
await HHiveCore.initialize();

// Individual Box - can register anytime, opens lazily
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'temp_${DateTime.now().millisecondsSinceEpoch}',
  type: HiveBoxType.box,
));
```

### BoxCollectionConfig

Optionally pre-configure collections with custom settings:

```dart
// Pre-configure collection (before any HiveConfig registration)
HHiveCore.registerCollection(BoxCollectionConfig(
  name: 'myapp',
  storagePath: '/custom/path',      // Overrides global path
  encryptionCipher: myCipher,       // Overrides global cipher
  includeMeta: true,                // Force meta box inclusion
));

// HiveConfigs reference the collection
HHiveCore.register(HiveConfig(env: 'users', boxCollectionName: 'myapp'));
HHiveCore.register(HiveConfig(env: 'orders', boxCollectionName: 'myapp'));
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | `String` | required | Collection identifier |
| `storagePath` | `String?` | global | Storage path override |
| `encryptionCipher` | `HiveCipher?` | global | Encryption cipher override |
| `includeMeta` | `bool?` | auto-detect | `null`=auto, `true`=force, `false`=forbid |

### Initialization Options

```dart
// Custom storage path (passed to initialize)
await HHiveCore.initialize(path: '/custom/path');

// Or set globally before initialize
HHiveCore.storagePath = '/custom/path';
await HHiveCore.initialize();
```

### Creating Instances

```dart
// From registered config
final hive = await HHive.create('myapp');

// With inline config (auto-registers)
final hive = await HHive.createFromConfig(HiveConfig(
  env: 'orders',
  withMeta: true,
  hooks: [...],
));
```

## Learn More

- [hihook](https://pub.dev/packages/hihook) - The hook engine powering HiveHook
- [Hive CE](https://pub.dev/packages/hive_ce) - The storage backend
