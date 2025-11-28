# System Patterns

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│            HHive (API Layer)                │
│  - User-facing methods (get, put, delete)   │
│  - Emits action events                      │
│  - Controls hook execution flow             │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│         HHCtx (Context Layer)               │
│  - HHCtxControl: Hook execution engine      │
│  - HHCtxDirectAccess: Data access layer     │
│  - HHCtxData: Runtime data storage          │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│         Hive (Storage Layer)                │
│  - CollectionBox<String> for data           │
│  - CollectionBox<String> for metadata       │
└─────────────────────────────────────────────┘
```

## Critical Architecture Decision: Layer Separation

### The Infinite Loop Problem (SOLVED)
**Problem**: If `HHCtxDirectAccess.storeGet()` emits `valueRead` events, and a hook calls `hive.get()`, it creates:
```
storeGet() → emit(valueRead) → hook → hive.get() → storeGet() → [INFINITE LOOP]
```

**Solution**: Separate action events from data access
- **HHive methods** emit action events (`valueRead`, `valueWrite`, etc.)
- **HHCtxDirectAccess methods** only handle serialization (no action events)

This allows hooks to safely call HiveHook methods without recursion.

## Key Components

1. **HHive**: User API, emits action events at boundary
2. **HHCtxControl**: Executes pre/post hooks by priority, handles `HHCtrlException`
3. **HHCtxDirectAccess**: Storage access, applies serialization hooks
4. **Configuration**: Mutable `HHConfig` → `.finalize()` → immutable `HHImmutableConfig`

See [details/sp_architecture_layers.md](details/sp_architecture_layers.md) for detailed component info.
**Responsibility**: Direct storage access with serialization

**Pattern**:
```dart
Future<dynamic> storeGet(String key) async {
  final box = await store;
  final rawResult = await box.get(key);
  if (rawResult == null) return null;

  // Terminal deserialization
  String valueStr = await ctx.control.emit(
    TriggerType.onValueTDeserialize.name,  // ← Only serialization events
    action: (ctx) async { /* ... */ },
  );

  // Application serialization
  final deserializedValue = await ctx.control.emit(
    TriggerType.onValueDeserialize.name,
    action: (ctx) async { /* ... */ },
  );

  return deserializedValue;
}
```

**Key Pattern**: Updates `ctx.payload` before calling serialization hooks:
```dart
ctx.payload = ctx.payload.copyWith(value: result);
result = await hook.deserialize(ctx);
```

### 4. Configuration System
**Location**: `lib/core/config.dart`

**Pattern**: Immutable configuration with builder
```dart
HHConfig (mutable) → .finalize() → HHImmutableConfig (immutable)
```

**Hook Organization**:
- `preActionHooks`: Map of event name → list of hooks
- `postActionHooks`: Map of event name → list of hooks
- Hooks are sorted by priority (higher = earlier)

### 5. Hook Types

#### Action Hooks
Execute custom logic around operations:
```dart
HActionHook(
  latches: [HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 10)],
  action: (ctx) async { /* logic */ },
)
```

#### Serialization Hooks
Transform **store values** during read/write:
```dart
SerializationHook(
  serialize: (ctx) async => /* transform value to string */,
  deserialize: (ctx) async => /* transform string to value */,
  forStore: true,  // Only applies to store values, NOT metadata
)
```

**Important**: `SerializationHook` is **only for store values**. Metadata is always `Map<String, dynamic>` and directly JSON encoded/decoded.

**Two levels**:
1. **Application Hooks**: User-defined transformations (custom serialization)
2. **Terminal Hooks**: Final transformations (encryption, compression, base64)

**For Metadata**:
- No `SerializationHook` applied (metadata is already JSON)
- Only `TerminalSerializationHook` applied (for encryption/compression of JSON string)

### 6. Plugin System
**Location**: `lib/helper/plugin.dart`
**Responsibility**: Group and manage related hooks as a unit

**Pattern**:
```dart
class HHPlugin {
  final String name;
  final String? description;
  final List<HActionHook> actionHooks;
  final List<SerializationHook> serializationHooks;
  final List<TerminalSerializationHook> terminalSerializationHooks;
}
```

**Installation**:
```dart
// On mutable HHConfig only
config.installPlugin(plugin);  // Adds all hooks, tracks in map
config.uninstallPlugin('plugin_name');  // Removes hooks by UID

// On HHImmutableConfig - throws UnsupportedError
immutableConfig.installPlugin(plugin);  // ❌ ERROR
```

**Hook UID System**:
- All hooks extend `BaseHook` which provides auto-incrementing UIDs
- Format: `'hook_0'`, `'hook_1'`, `'hook_2'`, ...
- UIDs enable tracking which hooks belong to which plugin
- Uninstall removes hooks by matching UIDs

## Data Flow

### Write Operation
```
User → hive.put(key, value)
  ↓
HHive.staticPut()
  ↓ emit(valueWrite)
  ↓
  ├─→ Pre-action hooks
  ↓
HHCtxDirectAccess.storePut()
  ↓ emit(onValueSerialize)
  ├─→ Application serialization hooks
  ↓ emit(onValueTSerialize)
  ├─→ Terminal serialization hooks
  ↓
Hive box.put(key, serializedValue)
  ↓
  ├─→ Post-action hooks
  ↓
Return to user
```

## Data Flow Patterns
**Write**: HHive.put → emit(valueWrite) → pre-hooks → storePut → serialize hooks → terminal hooks → Hive box.put → post-hooks
**Read**: HHive.get → emit(valueRead) → pre-hooks → storeGet → terminal deserialize → serialize deserialize → post-hooks → return
**Metadata**: Always `Map<String, dynamic>` → JSON encode/decode → terminal hooks only

See [details/sp_pattern_dataflow.md](details/sp_pattern_dataflow.md) for detailed flows.

## Design Patterns Used

1. **Factory Pattern**: `HHive` uses factory constructor for singleton instances per environment
2. **Context Object**: Rich context passed through hook chain
3. **Chain of Responsibility**: Hooks execute in sequence, can modify flow
4. **Strategy Pattern**: Different hook types implement different strategies
5. **Immutable Configuration**: Configuration finalized before use
6. **Exception-based Control Flow**: `HHCtrlException` for flow control

## Critical Implementation Details

### Payload Updates in Serialization
Hooks don't receive value as parameter, they read from context:
```dart
// Before calling hook, update payload
ctx.payload = ctx.payload.copyWith(value: result);
// Hook reads from ctx.payload.value
result = await hook.deserialize(ctx);
```

### Environment Isolation
Each environment has its own:
- Configuration instance
- Hive boxes (data and metadata)
- Hook registry

### Singleton Management
- `HHive` instances: One per environment
- `HHImmutableConfig` instances: One per environment
- Both use `Map<String, Instance>` for storage
