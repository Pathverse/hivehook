# Active Context

## Current Status: ✅ Stable - Infinite Loop Fixed

### Recent Changes (November 26, 2025)

#### Plugin System Implementation ✅ COMPLETE
**Feature Added**: Group hooks into plugins for easier management

**New Components**:
1. `lib/helper/plugin.dart`:
   - `HHPlugin` class with name, description, and hook collections
   - Containers for actionHooks, serializationHooks, terminalSerializationHooks

2. `lib/hooks/base_hook.dart`:
   - Base class for all hooks providing UID system
   - Auto-incrementing counter: `'hook_0'`, `'hook_1'`, ...
   - All hook types (HActionHook, SerializationHook, TerminalSerializationHook) extend BaseHook

3. `lib/core/config.dart` enhancements:
   - `installPlugin(HHPlugin)`: Adds all plugin hooks to config lists
   - `uninstallPlugin(String)`: Removes hooks by UID matching
   - `installedPlugins`: Read-only map of installed plugins
   - Lists changed to mutable (using `List.from()` in constructor)
   - `HHImmutableConfig.installPlugin/uninstallPlugin`: Throw `UnsupportedError`

**Usage Pattern**:
```dart
// Create plugin
final plugin = HHPlugin(
  name: 'logging',
  description: 'Logs operations',
  actionHooks: [/* hooks */],
);

// Install on mutable config
final config = HHConfig(env: 'app', usesMeta: true);
config.installPlugin(plugin);
final finalConfig = config.finalize();  // Now immutable

// Uninstall removes all plugin hooks by UID
config.uninstallPlugin('logging');
```

**Test Results**: ✅ All 8 plugin tests passing
- Install/uninstall functionality
- Hook execution after install
- Duplicate prevention
- Missing plugin errors
- Immutable config error handling
- UID tracking
- Multiple plugin support

**Total Test Count**: 50 tests (42 original + 8 plugin tests)

#### Critical Bug Fix: Infinite Loop in Hook Execution
**Problem Identified**:
- `HHCtxDirectAccess.storeGet()` was emitting `valueRead` action events
- When action hooks called `hive.get()`, it would recursively call `storeGet()`
- This created an infinite loop: `storeGet() → valueRead event → hook → hive.get() → storeGet() → ...`

**Solution Implemented**:
- Moved action event emission from `HHCtxDirectAccess` to `HHive` layer
- `HHCtxDirectAccess` now only handles serialization events (no action events)
- Action events (`valueRead`, `valueWrite`, etc.) now emitted at API boundary in `HHive.static*` methods

**Files Modified**:
1. `lib/core/ctx.dart`:
   - Removed `valueRead` event emission from `storeGet()`
   - Removed `valueWrite` event emission from `storePut()`
   - Removed `metadataRead` event emission from `metaGet()`
   - Removed `metadataWrite` event emission from `metaPut()`
   - Added payload updates before calling serialization hooks

2. `lib/core/hive.dart`:
   - Added `valueRead` event emission to `staticGet()`
   - Added `valueWrite` event emission to `staticPut()`
   - Added `metadataRead` event emission to `staticGetMeta()`
   - Added `metadataWrite` event emission to `staticPutMeta()`

3. Debug logs commented out:
   - `lib/core/ctx.dart`: Hook execution count logging
   - `lib/core/config.dart`: Configuration replacement logging

**Test Results**: ✅ All 42 tests passing

## Current Architecture

### Layer Responsibilities (IMPORTANT)

```
┌─────────────────────────────────────────────┐
│  HHive (API Layer)                          │
│  Responsibility:                            │
│  - Emit ACTION events                       │
│    (valueRead, valueWrite, onDelete, etc.)  │
│  - Handle control flow exceptions           │
│  - User-facing API                          │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  HHCtxDirectAccess (Access Layer)           │
│  Responsibility:                            │
│  - Emit SERIALIZATION events only           │
│    (onValueSerialize, onValueDeserialize)   │
│  - Direct box access                        │
│  - NO ACTION EVENTS                         │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  Hive (Storage)                             │
└─────────────────────────────────────────────┘
```

**Critical Rule**: `HHCtxDirectAccess` must NEVER emit action events. This prevents infinite loops.

## Next Steps / TODO

### Potential Improvements
- [ ] Add query/filter hooks for read operations
- [ ] Implement batch operation support with hooks
- [ ] Add performance monitoring hooks
- [ ] Create hook composition utilities
- [ ] Add hook debugging tools
- [ ] Consider adding hook dependency resolution

### Documentation
- [ ] Add comprehensive API documentation
- [ ] Create hook cookbook with common patterns
- [ ] Add migration guide from plain Hive
- [ ] Document performance characteristics
- [ ] Create troubleshooting guide

### Testing
- [ ] Add performance benchmarks
- [ ] Add stress tests for hook chains
- [ ] Test multi-isolate scenarios
- [ ] Add mutation testing

## Known Limitations

1. **String-Only Storage**: All values must be serializable to strings
2. **No Querying**: No built-in query system beyond Hive's basic get/put
3. **Single Isolate**: Not designed for multi-isolate concurrent access
4. **Synchronous Hooks**: All hooks must be async, no sync hook support
5. **No Hook Dependencies**: Hooks can't declare dependencies on other hooks

## Critical Testing Patterns (NEVER REPEAT THESE MISTAKES)

### Test Configuration Initialization Pattern
**Established in**: `test/all_tests.dart`, `test/test_configs.dart`, `test/hooks_test.dart`, `test/control_flow_test.dart`

**THE CORRECT WAY**:
```dart
setUpAll(() async {
  // Step 1: Create configs BEFORE HHiveCore.initialize()
  HHImmutableConfig(env: 'test_env', usesMeta: true);
  
  // Step 2: Initialize HHiveCore (registers box names)
  await HHiveCore.initialize();
});

test('dynamic hooks', () async {
  final config = HHConfig(
    env: 'test_env',  // MUST match pre-registered env
    usesMeta: true,
    actionHooks: [/* dynamic hooks */],
  );
  
  // Pass mutable config, NOT finalized
  dangerousReplaceConfig(config);  // ✅ CORRECT
  
  final hive = HHive(config: HHImmutableConfig.getInstance('test_env')!);
  // test...
});
```

**MISTAKES TO AVOID**:

❌ **Mistake 1**: Not pre-registering env before HHiveCore.initialize()
```dart
setUpAll(() async {
  await HHiveCore.initialize();  // Boxes registered
});

test('...', () async {
  // This env was never registered!
  final config = HHConfig(env: 'new_env', usesMeta: true);
  // Result: "Box with name new_env is not in the known box names"
});
```

❌ **Mistake 2**: Calling `.finalize()` before `dangerousReplaceConfig()`
```dart
final config = HHConfig(env: 'test_env', usesMeta: true, ...);
dangerousReplaceConfig(config.finalize());  // WRONG!
// Result: "Config with env already exists with different settings"
// Why: dangerousReplaceConfig calls .finalize() internally
```

❌ **Mistake 3**: Creating config in setUpAll that will be dynamically replaced
```dart
setUpAll(() async {
  HHImmutableConfig(env: 'test_env', usesMeta: true);  // Empty config
  await HHiveCore.initialize();
});

test('...', () async {
  // Trying to replace with different config
  final config = HHConfig(env: 'test_env', usesMeta: true, actionHooks: [...]);
  dangerousReplaceConfig(config);
  // Can work, but be aware config identity checks may fail if not careful
});
```

**WHY THIS PATTERN EXISTS**:
1. Hive requires box names registered during `BoxCollection.open()`
2. Box names come from configs created BEFORE `HHiveCore.initialize()`
3. `dangerousReplaceConfig()` removes old instance, creates new via `.finalize()`
4. Tests with dynamic hooks need placeholder configs for box registration

**PATTERN VIOLATED**: Plugin tests initially failed with these exact errors until pattern was followed

## Important Patterns to Remember

### Serialization Hook Pattern
Hooks receive context, must update payload:
```dart
// CORRECT
ctx.payload = ctx.payload.copyWith(value: result);
result = await hook.deserialize(ctx);

// WRONG - Don't pass value directly, hook signature doesn't support it
result = await hook.deserialize(result, ctx);
```

### Event Emission Pattern
```dart
// In HHive (API layer) - OK to emit action events
await ctx.control.emit(
  TriggerType.valueRead.name,
  action: (ctx) async => await ctx.access.storeGet(key),
  handleCtrlException: true,
);

// In HHCtxDirectAccess - NEVER emit action events
// Only emit serialization events
await ctx.control.emit(
  TriggerType.onValueDeserialize.name,  // Serialization event OK
  action: (ctx) async { /* ... */ },
);
```

### Control Flow Pattern
```dart
// In a hook - break early
ctx.control.breakEarly(returnValue, {'reason': 'cached'});

// Framework catches HHCtrlException and handles it
```

## Active Development Notes

### Debugging Tips
1. If you see infinite loops, check that action events aren't emitted in `HHCtxDirectAccess`
2. If hooks aren't executing, verify they're registered in config and priority is set
3. If payload.value is wrong in hooks, check that `copyWith` is called before hook invocation

### Code Quality
- All debug logs are commented out for production
- Test coverage is comprehensive
- Linter rules enforced via `analysis_options.yaml`
- All async operations properly awaited

## Recent Learnings

1. **Layer Separation is Critical**: Mixing concerns between layers causes infinite recursion
2. **Context Updates Matter**: Serialization hooks need updated context before execution
3. **Exception-Based Control Flow**: Works well for breaking out of deep call stacks
4. **Immutable Configuration**: Prevents runtime bugs and enables safe concurrent access
5. **Test Isolation**: Each test needs unique environment to avoid interference
