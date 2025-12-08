# Recent Change: Cache Control & Utility Improvements (December 8, 2025)

## Overview
Version 0.1.6 added new cache control features and utility methods to improve flexibility and convenience.

## Changes

### 1. cacheOnNullValues Parameter

**Purpose**: Provide control over whether null values from compute functions should be cached

**Implementation**:
```dart
Future<T?> ifNotCached<T>(
  String key,
  Future<T?> Function() computeFn, {
  bool cacheOnNullValues = true,  // ← New parameter
}) async {
  final existing = await get(key);
  if (existing != null) return existing as T;
  
  final computed = await computeFn();
  if (computed != null || cacheOnNullValues) {  // ← Conditional caching
    await put(key, computed);
  }
  return computed;
}
```

**Use Cases**:
- When `cacheOnNullValues = true` (default): Cache everything, including null results
  - Useful when null is a valid cacheable result (e.g., "user not found")
  - Prevents repeated expensive computations that return null
  
- When `cacheOnNullValues = false`: Skip caching null values
  - Useful when null indicates a transient failure
  - Allows retry on next access rather than caching failure

**API Methods**:
- `ifNotCached<T>()` - Instance method
- `ifNotCachedStatic<T>()` - Static method

### 2. Static clearAll() Method

**Purpose**: Clear all data across all registered environments

**Implementation**:
```dart
static Future<void> clearAll() async {
  await HHiveCore._ensureInitialized();
  for (final env in HHImmutableConfig.instances.keys) {
    final config = HHImmutableConfig.getInstance(env);
    if (config != null) {
      final hive = HHive(config: config);
      await hive.clear();
    }
  }
}
```

**Use Cases**:
- Application reset/logout
- Testing cleanup
- Development/debugging
- Cache invalidation across environments

**Behavior**:
- Clears both values and metadata (if `usesMeta: true`)
- Respects environment isolation
- Executes hooks for each environment's clear operation

### 3. usesMeta Default Change

**Breaking Change**: Changed default from `false` to `true`

**Rationale**:
- Metadata is a core feature of HiveHook
- Most use cases benefit from metadata support
- Better developer experience out-of-the-box
- Aligns with common usage patterns

**Migration**:
Existing code that explicitly sets `usesMeta: false` is unaffected:
```dart
// Still works as before
HHConfig(env: 'myenv', usesMeta: false)
```

New code without explicit `usesMeta` now gets metadata support:
```dart
// Before 0.1.6: usesMeta defaults to false
// After 0.1.6: usesMeta defaults to true
HHConfig(env: 'myenv')  // Now has metadata support
```

## Files Modified

- `lib/core/hive.dart`:
  - Added `cacheOnNullValues` parameter to `ifNotCached()`
  - Added `cacheOnNullValues` parameter to `ifNotCachedStatic()`
  - Implemented static `clearAll()` method

- `lib/core/config.dart`:
  - Changed `usesMeta` default value from `false` to `true`

## Testing

All existing tests pass with these changes:
- 42 functional tests
- 6 performance benchmark tests

No new tests were added as these are straightforward feature additions to existing tested methods.

## Impact

**Backward Compatibility**:
- `cacheOnNullValues`: Fully backward compatible (default behavior unchanged)
- `clearAll()`: New method, no breaking changes
- `usesMeta`: **Breaking change** for code that relies on implicit `false` default

**Performance**: No impact, features are opt-in or have negligible overhead

**Developer Experience**: Improved with more control and convenience methods
