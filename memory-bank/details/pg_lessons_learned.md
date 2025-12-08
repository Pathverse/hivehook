# Lessons Learned

## Architecture & Design

1. **Layer separation prevents recursion**: Keep action events at API boundary. Essential for preventing infinite recursion in hook systems where hooks can trigger the operations they're monitoring.

2. **Immutability prevents bugs**: Finalize config before use. Prevents runtime configuration changes that could cause inconsistent behavior.

3. **Separation of concerns is essential**: Not just good practice—it's critical for hook systems to avoid infinite loops.

## Performance

4. **Profile before optimizing**: Exception overhead (~1-2μs) is negligible vs database I/O (100μs-10ms+). Measured before deciding on control flow approach.

5. **API ergonomics matter**: Exception-based control flow is cleaner than forcing all hooks to return wrapped results. Saves ~2μs while adding significant boilerplate.

## Development Practices

6. **Context updates enable transformation chains**: Update payload between hooks so each hook sees the result of previous transformations.

7. **Test isolation is crucial**: Unique environments prevent test interference. Each test should use its own environment name.

8. **Debug logs should be removable**: Comment out, don't delete. Keeps codebase clean while preserving debugging capability.

## Testing Patterns

9. **Test patterns must be followed religiously**: Tests with dynamic hooks MUST pre-register env names before HHiveCore.initialize(). Individual test files fail without centralized initialization.

10. **Test initialization is centralized**: All tests MUST run through `all_tests.dart` to ensure proper HHiveCore initialization and config registration.

11. **Box registration happens once**: Hive registers box names during initialize() - can't add new envs afterward. Plan environment names upfront.

12. **dangerousReplaceConfig takes mutable config**: Pass HHConfig, not HHImmutableConfig - it calls .finalize() internally. Common mistake during test setup.

## Design Evolution

### Initial Design Problem
- Action events emitted in access layer
- **Result**: Infinite loops when hooks called HiveHook methods

### Current Design Solution
- Action events emitted in API layer
- Access layer only handles serialization
- **Result**: Safe recursion, clean separation
