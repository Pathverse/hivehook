# Tech Context

## Technology Stack

### Core Dependencies
- **Dart**: Primary programming language
- **hive_ce**: Community edition of Hive (NoSQL database)
- **test**: Dart testing framework

### Language Features Used
- Async/await for asynchronous operations
- Future-based APIs
- Generic types (`CollectionBox<String>`)
- Named parameters with defaults
- Factory constructors
- Abstract classes and interfaces
- Exception handling with custom exceptions

## Project Structure

```
hivehook/
├── lib/
│   ├── hivehook.dart          # Main export file
│   ├── core/
│   │   ├── base.dart          # HHiveCore wrapper
│   │   ├── config.dart        # Configuration classes
│   │   ├── ctx.dart           # Context implementations
│   │   ├── enums.dart         # Enums (TriggerType, NextPhase)
│   │   ├── hive.dart          # Public API (HHive)
│   │   ├── i_ctx.dart         # Context interfaces
│   │   ├── latch.dart         # Hook latch definitions
│   │   └── payload.dart       # Payload data classes
│   ├── hooks/
│   │   ├── base_hook.dart          # Base class with UID system
│   │   ├── action_hook.dart        # Action hook implementation
│   │   └── serialization_hook.dart # Serialization hook implementation
│   ├── helper/
│   │   └── plugin.dart        # Plugin container class
│   └── templates/             # (Empty - for future use)
├── test/
│   ├── all_tests.dart         # Test suite runner
│   ├── config_test.dart       # Configuration tests
│   ├── control_flow_test.dart # Control flow tests
│   ├── crud_test.dart         # CRUD operation tests
│   ├── hooks_test.dart        # Hook execution tests
│   ├── metadata_test.dart     # Metadata operation tests
│   └── test_configs.dart      # Shared test configurations
├── memory-bank/               # Project documentation
├── pubspec.yaml               # Package configuration
├── analysis_options.yaml      # Linter configuration
└── dart_test.yaml            # Test configuration
```

## Development Setup

### Prerequisites
- Dart SDK (latest stable)
- IDE: VS Code or IntelliJ IDEA with Dart plugin

### Running Tests
```bash
dart test                    # Run all tests
dart test test/all_tests.dart  # Run specific test suite
```

### Linting
```bash
dart analyze
```

## Technical Constraints

### Storage Limitations
- All data stored as strings (requires serialization)
- Metadata stored as JSON strings
- No built-in indexing or querying (Hive limitation)

### Concurrency
- Not thread-safe across isolates
- Each isolate should use its own Hive instance
- Warning system for multi-isolate access

### Type System
- Dynamic typing for values (stored as strings)
- Strong typing for configuration and hooks
- Generic types used where appropriate

## Key Technical Decisions

### 1. String-Based Storage
**Decision**: All values stored as strings
**Rationale**: 
- Hive uses `CollectionBox<String>`
- Simplifies serialization pipeline
- User handles type conversion

### 2. Immutable Configuration
**Decision**: Configuration finalized before use, then immutable
**Rationale**:
- Prevents runtime modifications
- Enables safe concurrent access
- Simplifies reasoning about state

### 3. Context-Based Hook API
**Decision**: Hooks receive context object, not individual parameters
**Rationale**:
- Extensible (can add properties without breaking API)
- Rich access to operation details
- Enables hook coordination through shared data

### 4. Exception-Based Control Flow
**Decision**: Use `HHCtrlException` for flow control
**Rationale**:
- Dart's exception propagation natural for breaking out of call stack
- Clear separation between errors and control flow
- Type-safe with structured data

### 5. Dual Hook System
**Decision**: Separate action hooks and serialization hooks
**Rationale**:
- Different concerns (business logic vs data transformation)
- Different signatures (void vs transform)
- Different execution points

### 6. Two-Level Serialization
**Decision**: Application hooks + Terminal hooks
**Rationale**:
- Terminal hooks for infrastructure (compression, encoding)
- Application hooks for business logic (JSON, validation)
- Clear ordering: terminal hooks run closest to storage

## Performance Considerations

### Hook Execution Overhead
- Each operation triggers multiple hook executions
- Pre/post hooks run even if empty list
- Consider hook count vs benefit trade-off

### Serialization Chains
- Each hook adds transformation overhead
- Long serialization chains impact performance
- Order terminal hooks for efficiency

### Box Access
- Async box access on every operation
- Consider caching strategies at application level
- Metadata operations double the box access

## Testing Strategy

### Test Organization
1. **Unit Tests**: Individual component testing
   - Configuration creation and validation
   - Hook registration and sorting
   - Payload manipulation

2. **Integration Tests**: Multi-component interaction
   - CRUD operations with hooks
   - Serialization pipelines
   - Control flow scenarios
   - Metadata operations

3. **Test Isolation**: Each test uses unique environment
   - Prevents test interference
   - Enables parallel test execution
   - Clean slate for each test

### Test Patterns

#### Standard Test Pattern (Static Configs)
```dart
test('description', () async {
  // Arrange
  final config = HHConfig(env: 'unique_env', ...);
  
  // Act
  final hive = HHive(config: config);
  await hive.put('key', 'value');
  
  // Assert
  expect(await hive.get('key'), equals('value'));
});
```

#### Dynamic Hook Test Pattern
**CRITICAL: Must follow established pattern to avoid box registration errors**

```dart
setUpAll(() async {
  // 1. Register ALL env names BEFORE HHiveCore.initialize()
  // Even if hooks will be added dynamically via dangerousReplaceConfig
  HHImmutableConfig(env: 'test_env', usesMeta: true);
  
  // 2. THEN initialize HHiveCore (registers box names)
  await HHiveCore.initialize();
});

test('with dynamic hooks', () async {
  final env = 'test_env';
  
  // Create mutable config with hooks
  final config = HHConfig(
    env: env,
    usesMeta: true,
    actionHooks: [/* dynamic hooks */],
  );
  
  // Replace config - pass MUTABLE config, NOT .finalize()
  dangerousReplaceConfig(config);  // ✅ CORRECT
  // dangerousReplaceConfig(config.finalize());  // ❌ WRONG
  
  // Get finalized instance and use
  final finalConfig = HHImmutableConfig.getInstance(env)!;
  final hive = HHive(config: finalConfig);
  
  // Test
});
```

**Why This Pattern Matters**:
1. **Box Registration**: `HHiveCore.initialize()` registers box names based on configs created BEFORE it runs
2. **Config Lifecycle**: Empty placeholder → HHiveCore.initialize() → dangerousReplaceConfig with hooks
3. **Common Mistake**: Creating config in test without pre-registering → "Box not in known names" error
4. **Another Mistake**: Calling `.finalize()` before dangerousReplaceConfig → "Config already exists" error

**Pattern Used In**:
- `test/hooks_test.dart` - All 8 tests
- `test/control_flow_test.dart` - All 7 tests  
- `test/plugin_test.dart` - All 8 tests

**Reference File**: `test/test_configs.dart` shows centralized config registration

## Future Technical Considerations

### Potential Enhancements
- Query hook system for filtering operations
- Batch operation hooks
- Transaction support
- Schema validation hooks
- Migration hooks
- Performance monitoring hooks

### Compatibility
- Maintain backward compatibility with Hive API
- Version serialization hooks for data migration
- Document breaking changes clearly
