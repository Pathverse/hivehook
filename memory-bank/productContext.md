# Product Context

## Problem Statement
When building applications with Hive database, developers often need to:
- Add logging to track data changes
- Validate data before saving
- Encrypt/decrypt sensitive data
- Transform data formats
- Implement business logic around data operations
- Handle metadata alongside values

Currently, this requires modifying code at every call site or creating wrapper functions, leading to scattered logic and code duplication.

## Solution
HiveHook provides a centralized hook system where developers can register functions to execute at specific points in the database operation lifecycle.

## User Experience Goals

### For Developers Using HiveHook

**Simple Setup**
```dart
final config = HHConfig(
  env: 'myapp',
  usesMeta: true,
  actionHooks: [/* hooks */],
);
final hive = HHive(config: config);
```

**Intuitive Hook Registration**
```dart
HActionHook(
  latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
  action: (ctx) async {
    // Custom logic here
    print('Writing ${ctx.payload.key}: ${ctx.payload.value}');
  },
)
```

**Transparent Operation**
Once configured, HiveHook works transparently:
```dart
await hive.put('key', 'value');  // Hooks execute automatically
final value = await hive.get('key');  // Hooks execute automatically
```

### Key User Benefits

1. **Centralized Logic**: All cross-cutting concerns in one place
2. **Reusability**: Define hooks once, use across entire app
3. **Composability**: Mix and match hooks for different behaviors
4. **Testability**: Test hooks independently of business logic
5. **Flexibility**: Control flow and transform data as needed

## Use Cases

### Logging and Auditing
Track all database operations for debugging or compliance:
```dart
HActionHook(
  latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
  action: (ctx) async {
    logger.info('Writing ${ctx.payload.key} at ${DateTime.now()}');
  },
)
```

### Data Validation
Prevent invalid data from being stored:
```dart
HActionHook(
  latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
  action: (ctx) async {
    if (!isValid(ctx.payload.value)) {
      throw HHRuntimeException('Invalid data');
    }
  },
)
```

### Encryption/Decryption
Automatically encrypt on write, decrypt on read:
```dart
SerializationHook(
  serialize: (ctx) async => encrypt(ctx.payload.value),
  deserialize: (ctx) async => decrypt(ctx.payload.value),
)
```

### Caching
Implement automatic caching with metadata:
```dart
await hive.put('key', 'value', meta: {'cachedAt': DateTime.now().toString()});
```

### Plugin-Based Features
Group related hooks into reusable plugins:
```dart
final loggingPlugin = HHPlugin(
  name: 'logging',
  description: 'Logs all operations',
  actionHooks: [/* logging hooks */],
);

final config = HHConfig(env: 'myapp', usesMeta: true);
config.installPlugin(loggingPlugin);
// Later: config.uninstallPlugin('logging');
```

## How It Should Work

### Hook Lifecycle
1. User calls `hive.put('key', 'value')`
2. HHive emits `valueWrite` action event
3. Pre-hooks execute in priority order
4. Serialization hooks transform the data
5. Data is written to Hive
6. Post-hooks execute
7. Control returns to user

### Control Flow
Hooks can modify execution:
- `f_skip`: Skip remaining hooks in batch
- `f_break`: Stop execution, return value
- `f_continue`: Continue to next hook
- `f_delete`: Delete key and stop
- `f_pop`: Return current value and delete
- `f_panic`: Throw exception

### Context Access
Hooks receive a context object with:
- `payload`: Current key, value, metadata
- `control`: Methods to control execution flow
- `access`: Direct access to storage (use carefully!)
- `data`: Runtime data storage for passing info between hooks
- `config`: Current configuration

## Design Philosophy

1. **Separation of Concerns**: API layer handles events, access layer handles data
2. **No Magic**: Explicit hook registration, clear execution order
3. **Safe Recursion**: Hooks can call HiveHook methods without infinite loops
4. **Fail-Safe**: Errors in hooks can be caught and handled gracefully
