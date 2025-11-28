# Plugin System & Infinite Loop Fix (Nov 26, 2025)

## Plugin System Implementation

### New Components
1. **`lib/helper/plugin.dart`**: `HHPlugin` container with name, description, hook lists
2. **`lib/hooks/base_hook.dart`**: Base class with auto-incrementing UID system (`hook_0`, `hook_1`, ...)
3. **`lib/core/config.dart`**: `installPlugin()` / `uninstallPlugin()` methods

### Key Changes
- All hooks now extend `BaseHook` for UID tracking
- Config lists changed to mutable (using `List.from()`)
- `HHImmutableConfig` throws `UnsupportedError` for plugin operations
- Plugins tracked in `_installedPlugins` map
- Uninstall removes hooks by UID matching

### Usage
```dart
final plugin = HHPlugin(name: 'logging', actionHooks: [...]);
config.installPlugin(plugin);  // On mutable config only
config.uninstallPlugin('logging');
```

### Tests
8 plugin tests added (install/uninstall, duplicates, errors, UID tracking)

## Infinite Loop Bug Fix

### Problem
`HHCtxDirectAccess.storeGet()` emitted `valueRead` events → hook called `hive.get()` → infinite recursion

### Solution
**Architectural Refactoring**:
- Moved action event emission from `HHCtxDirectAccess` to `HHive` layer
- Access layer now only handles serialization events (safe for hooks)
- API layer handles action events at boundary

### Files Modified
1. **`lib/core/ctx.dart`**: Removed action events from `storeGet()`, `storePut()`, `metaGet()`, `metaPut()`
2. **`lib/core/hive.dart`**: Added action events to `staticGet()`, `staticPut()`, `staticGetMeta()`, `staticPutMeta()`

### Impact
Hooks can now safely call any HiveHook method without causing infinite loops.
