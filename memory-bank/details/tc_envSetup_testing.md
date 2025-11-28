# Testing Environment Setup - Detailed Patterns

## The Test Configuration Pattern

### Why This Pattern Exists

Hive requires box names to be registered during `BoxCollection.open()`. Box names come from config environment names. If a config's env isn't registered before initialization, Hive throws: "Box with name X is not in the known box names".

### The Correct Pattern

```dart
setUpAll(() async {
  // STEP 1: Pre-register ALL environment names
  HHImmutableConfig(env: 'test_env_1', usesMeta: true);
  HHImmutableConfig(env: 'test_env_2', usesMeta: true);
  HHImmutableConfig(env: 'hooks_pre', usesMeta: true);
  
  // STEP 2: Initialize HHiveCore (opens BoxCollection with registered names)
  await HHiveCore.initialize();
});

test('dynamic hooks test', () async {
  // STEP 3: Create config with SAME env name
  final config = HHConfig(
    env: 'hooks_pre',  // Must match pre-registered env
    usesMeta: true,
    actionHooks: [/* dynamic hooks for this test */],
  );
  
  // STEP 4: Replace config (pass mutable config, NOT finalized)
  dangerousReplaceConfig(config);  // ✅ CORRECT - config is mutable
  
  // STEP 5: Get finalized config instance
  final hive = HHive(config: HHImmutableConfig.getInstance('hooks_pre')!);
  
  // Test logic...
});
```

## Common Mistakes

### Mistake 1: Not Pre-Registering Env

```dart
// ❌ WRONG
setUpAll(() async {
  await HHiveCore.initialize();  // Boxes registered with no envs
});

test('...', () async {
  // This env was never registered!
  final config = HHConfig(env: 'new_env', usesMeta: true);
  dangerousReplaceConfig(config);
  // ERROR: "Box with name new_env is not in the known box names"
});
```

**Why it fails**: `new_env` wasn't in the list when `BoxCollection.open()` was called.

### Mistake 2: Calling finalize() Before dangerousReplaceConfig()

```dart
// ❌ WRONG
final config = HHConfig(env: 'test_env', usesMeta: true, actionHooks: [...]);
dangerousReplaceConfig(config.finalize());  // finalize() called externally

// ERROR: "Config with env 'test_env' already exists with different settings"
```

**Why it fails**: `dangerousReplaceConfig()` calls `.finalize()` internally. Calling it twice creates two instances with same env name.

**Correct**:
```dart
// ✅ CORRECT
final config = HHConfig(env: 'test_env', usesMeta: true, actionHooks: [...]);
dangerousReplaceConfig(config);  // Pass mutable config
```

### Mistake 3: Creating Different Config in Test

```dart
// ⚠️ PROBLEMATIC
setUpAll(() async {
  HHImmutableConfig(env: 'test_env', usesMeta: true, actionHooks: []);
  await HHiveCore.initialize();
});

test('...', () async {
  // Different hook list from setUpAll
  final config = HHConfig(
    env: 'test_env',
    usesMeta: true,
    actionHooks: [hook1, hook2],  // Different from empty list above
  );
  dangerousReplaceConfig(config);
  // May work, but config identity checks might fail
});
```

**Better**: Use placeholder config in `setUpAll`, replace with actual config in test.

## File-Specific Patterns

### test/all_tests.dart
```dart
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hivehook_all_tests_');
    HHiveCore.HIVE_INIT_PATH = tempDir.path;
    HHiveCore.HIVE_BOX_COLLECTION_NAME = 'all_tests';

    // Initialize all configs ONCE
    initializeAllTestConfigs();  // From test_configs.dart
    await HHiveCore.initialize();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Run all test files
  config_test.main();
  crud_test.main();
  metadata_test.main();
  hooks_test.main();
  control_flow_test.main();
  plugin_test.main();
}
```

### test/test_configs.dart
```dart
void initializeAllTestConfigs() {
  // Config tests
  HHImmutableConfig(env: 'test_env', usesMeta: true);
  HHImmutableConfig(env: 'test_env_no_meta', usesMeta: false);

  // CRUD tests
  HHImmutableConfig(env: 'crud_put_get', usesMeta: true);
  HHImmutableConfig(env: 'crud_null', usesMeta: true);
  // ... more envs

  // Hook and control flow test placeholders
  HHImmutableConfig(env: 'hooks_pre', usesMeta: true);
  HHImmutableConfig(env: 'control_break', usesMeta: true);
  // ... more envs
}
```

### test/hooks_test.dart (Dynamic Hooks Pattern)
```dart
group('Hook Execution', () {
  test('should execute pre-action hooks before operation', () async {
    List<String> executionOrder = [];

    final config = HHConfig(
      env: 'hooks_pre',  // Matches placeholder from test_configs
      usesMeta: true,
      actionHooks: [
        HActionHook(
          latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
          action: (ctx) async {
            executionOrder.add('pre-hook');
          },
        ),
      ],
    );

    dangerousReplaceConfig(config);  // Pass mutable config

    final hive = HHive(config: HHImmutableConfig.getInstance('hooks_pre')!);
    
    await hive.put('test', 'value', meta: {'type': 'test'});
    executionOrder.add('after-put');

    expect(executionOrder, ['pre-hook', 'after-put']);
  });
});
```

## Testing Utilities

### dangerousReplaceConfig()
```dart
void dangerousReplaceConfig(dynamic config) {
  if (config is! HHConfig) {
    throw ArgumentError('Provided config is not of type HHConfig.');
  }
  
  if (config is HHImmutableConfig) {
    // Direct replacement of immutable config
    HHImmutableConfig._instances[config.env] = config;
  } else {
    // Remove old, finalize new, store new
    HHImmutableConfig._instances.remove(config.env);
    final finalizedConfig = config.finalize();
    HHImmutableConfig._instances[finalizedConfig.env] = finalizedConfig;
  }
}
```

**Usage**: Only in tests. Replaces existing config with new one (for dynamic hook testing).

### dangerousClearAllConfigs()
```dart
void dangerousClearAllConfigs() {
  HHImmutableConfig._instances.clear();
}
```

**Usage**: Only in tests. Clears all configs (use with caution - usually not needed).

### dangerousRemoveConfig()
```dart
void dangerousRemoveConfig(HHImmutableConfig config) {
  HHImmutableConfig._instances.remove(config.env);
}
```

**Usage**: Only in tests. Removes specific config.

## Running Tests

### Single Test File
```bash
dart test test/hooks_test.dart
```

### All Tests
```bash
dart test test/all_tests.dart
```

### With Coverage
```bash
dart test --coverage=coverage test/all_tests.dart
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## Test Organization

```
test/
├── all_tests.dart           - Main runner, initializes once
├── test_configs.dart        - Central config initialization
├── config_test.dart         - Configuration system tests
├── crud_test.dart           - Basic CRUD operations
├── metadata_test.dart       - Metadata operations
├── hooks_test.dart          - Hook execution (dynamic configs)
├── control_flow_test.dart   - Control flow exceptions
└── plugin_test.dart         - Plugin system
```

**Pattern**: `all_tests.dart` initializes once, each test file uses pre-registered envs or replaces with dynamic configs.
