# Product Context

## Why This Exists

hivehook separates storage from hook logic:
- **hihook** = Hook engine (storage-agnostic)
- **hivehook** = Hive storage adapter

## Problems Solved

1. **Type safety**: Typed payloads and conditions
2. **Isolation**: Env-prefixed keys prevent contamination
3. **Testability**: Test hooks without Hive, storage without hooks

## User Experience

```dart
final hive = await HHive.create('users');
await hive.put('key', 'value');
final value = await hive.get('key');
```

Internally:
```
HHive.put() → engine.emit('write', payload) → hooks → storage
```

## Success Criteria

- ✅ 112 tests passing
- ✅ Env isolation working
- ✅ Clean layered architecture
- [ ] Example app demonstrates integration
