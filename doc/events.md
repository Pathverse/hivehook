# Hook Events

HiveHook emits events during CRUD operations. Hooks can listen to these events to transform, validate, or log data.

## Event Reference

| Event | Method | Payload |
|-------|--------|---------|
| `put` | `hive.put(key, value)` | `key`, `value`, `meta` |
| `get` | `hive.get(key)` | `key` |
| `delete` | `hive.delete(key)` | `key` |
| `clear` | `hive.clear()` | — |

## Listening to Events

Use `HiHook` to listen to one or more events:

```dart
HiHook(
  uid: 'my-hook',
  events: ['put', 'get'],  // Listen to these events
  handler: (payload, ctx) {
    print('Event: ${payload.event}, Key: ${payload.key}');
    return const HiContinue();
  },
)
```

## Hook Results

Your handler must return one of:

| Result | Effect |
|--------|--------|
| `HiContinue()` | Continue to next hook, then storage |
| `HiContinue(payload: ...)` | Continue with modified payload |
| `HiBreak(returnValue: ...)` | Stop pipeline, return value immediately |

## Event Details

### `put`

Emitted when storing a value.

```dart
await hive.put('user:1', {'name': 'Alice'}, meta: {'ttl': 3600});
```

**Payload:**
- `key` — `'user:1'`
- `value` — `{'name': 'Alice'}`
- `metadata.meta` — `{'ttl': 3600}`

**Use cases:**
- Validate data before storage
- Transform values (add timestamps, compute fields)
- Log writes

### `get`

Emitted when retrieving a value.

```dart
final user = await hive.get('user:1');
```

**Payload:**
- `key` — `'user:1'`

**Use cases:**
- Check TTL expiration
- Log reads
- Transform output

### `delete`

Emitted when deleting a value.

```dart
await hive.delete('user:1');
```

**Payload:**
- `key` — `'user:1'`

**Use cases:**
- Log deletions
- Cascade deletes to related keys
- Prevent deletion (return `HiBreak`)

### `clear`

Emitted when clearing all keys in an environment.

```dart
await hive.clear();
```

**Payload:**
- No key or value

**Use cases:**
- Log clear operations
- Prevent clear (return `HiBreak`)

## Examples

### Validation Hook

Block invalid data:

```dart
HiHook(
  uid: 'validator',
  events: ['put'],
  handler: (payload, ctx) {
    final value = payload.value as Map?;
    if (value?['email'] == null) {
      return HiBreak(returnValue: {'error': 'Email required'});
    }
    return const HiContinue();
  },
)
```

### Transformation Hook

Add computed fields:

```dart
HiHook(
  uid: 'add-timestamp',
  events: ['put'],
  handler: (payload, ctx) {
    final value = payload.value as Map<String, dynamic>?;
    if (value != null) {
      final updated = {...value, 'updatedAt': DateTime.now().toIso8601String()};
      return HiContinue(payload: payload.copyWith(value: updated));
    }
    return const HiContinue();
  },
)
```

### Logging Hook

Log all operations:

```dart
HiHook(
  uid: 'logger',
  events: ['put', 'get', 'delete', 'clear'],
  handler: (payload, ctx) {
    print('[${payload.event}] ${payload.key ?? 'all'}');
    return const HiContinue();
  },
)
```
