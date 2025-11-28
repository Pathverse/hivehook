# Detailed Change History - November 2025

## November 27, 2025

### Bug Fix: Unnecessary Metadata Serialization
**Problem**: System applied `SerializationHook` transformations to metadata, but metadata is always `Map<String, dynamic>` and directly JSON encoded/decoded. Custom hooks would just transform JSON→JSON (pointless).

**Solution**:
- Removed `metaSerializationHooks` from `HHImmutableConfig`
- Removed `SerializationHook` loop from `metaGet()` and `metaPut()`
- Removed `forMeta` flag from `SerializationHook` class
- Kept `TerminalSerializationHook` for encryption/compression

**Files Modified**:
- `lib/core/config.dart`: Removed field and separation logic
- `lib/core/ctx.dart`: Simplified metadata methods
- `lib/hooks/serialization_hook.dart`: Removed parameter

**Test Results**: All 42 tests passing

## November 26, 2025

### Feature: Plugin System
**Implementation**:
- `lib/helper/plugin.dart`: `HHPlugin` container class
- `lib/hooks/base_hook.dart`: UID system (`hook_0`, `hook_1`, ...)
- `lib/core/config.dart`: `installPlugin()` / `uninstallPlugin()` methods

**Key Details**:
- All hooks extend `BaseHook` for UID tracking
- Config lists changed to mutable
- `HHImmutableConfig` throws `UnsupportedError` for plugin ops
- Plugins tracked in `_installedPlugins` map
- 8 plugin tests added

### Bug Fix: Infinite Loop
**Problem**: `HHCtxDirectAccess.storeGet()` emitted `valueRead` events. When hooks called `hive.get()`, created infinite recursion.

**Solution**:
- Moved action event emission from `HHCtxDirectAccess` to `HHive`
- Access layer now only handles serialization events
- API layer handles action events at boundary

**Files Modified**:
- `lib/core/ctx.dart`: Removed action events from access methods
- `lib/core/hive.dart`: Added action events to static methods

**Impact**: Hooks can now safely call any HiveHook method

### Enhancement: Serialization Context Updates
Added payload updates before calling serialization hooks:
```dart
ctx.payload = ctx.payload.copyWith(value: result);
result = await hook.deserialize(ctx);
```

## Testing Journey
Initial plugin tests failed: "Box not in known box names"

**Lesson Learned**: Tests with dynamic hooks MUST pre-register env names before `HHiveCore.initialize()`. Added placeholder configs in `setUpAll()` BEFORE initialization. Pattern now documented across all dynamic hook tests.
