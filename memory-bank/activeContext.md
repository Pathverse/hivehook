# Active Context

## Current Status
✅ Stable - All tests passing (42 functional + 6 performance benchmark)

## Current Focus
- System feature-complete and stable
- Performance validated: exception overhead ~1-2μs per call
- No active blockers

## Recent Changes (Last 3)

### Nov 28: Exception Performance Validation
Benchmarked `HHCtrlException` overhead: ~1-2μs per throw/catch. Confirmed exception-based control flow is performant and appropriate. Result pattern would save only ~2μs while adding boilerplate. Database I/O dominates (100μs-10ms+), making exception overhead negligible.

### Nov 27: SerializationHook ID-Wrapping Feature
SerializationHooks now encapsulate serialized values with hook ID using format `{"_hivehook__id_": hookId, "value": data}`. Enables routing deserialization to the specific hook that serialized the data. Identifier uses `_hivehook__id_` to avoid conflicts with user objects.

### Nov 27: Metadata Serialization Bug Fix
Removed metadata SerializationHooks - metadata is always `Map<String, dynamic>`, only needs JSON+terminal hooks. [Details](details/ac_recentChange_metaSerialization.md)

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
- [ ] Batch operations with context-aware hooks (see progress.md for design)
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
- [x] Exception performance benchmarks
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
3. **Exception Overhead is Negligible**: ~1-2μs per throw/catch, irrelevant vs database I/O (100μs-10ms+)
4. **Immutable Configuration**: Prevents runtime bugs and enables safe concurrent access
5. **Test Isolation**: Each test needs unique environment to avoid interference
6. **Profile Before Optimizing**: Benchmark showed exceptions are not a bottleneck
