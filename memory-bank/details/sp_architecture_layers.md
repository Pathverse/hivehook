# Detailed Architecture - Layer Responsibilities

## Complete Architecture Diagram

```
┌─────────────────────────────────────────────┐
│            HHive (API Layer)                │
│  - User-facing methods (get, put, delete)   │
│  - Emits action events                      │
│  - Controls hook execution flow             │
│  - Handles control flow exceptions          │
│  - Factory singleton per environment        │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│         HHCtx (Context Layer)               │
│  ┌───────────────────────────────────────┐  │
│  │ HHCtxControl: Hook execution engine   │  │
│  │ - emit() orchestrates hook batches    │  │
│  │ - invoke() handles exceptions          │  │
│  │ - breakEarly() for control flow       │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ HHCtxDirectAccess: Data access layer  │  │
│  │ - storeGet/Put: serialization hooks   │  │
│  │ - metaGet/Put: terminal hooks + JSON  │  │
│  │ - NEVER emits action events           │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ HHCtxData: Runtime data storage       │  │
│  │ - runtimeData map for hook state      │  │
│  └───────────────────────────────────────┘  │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│         Hive (Storage Layer)                │
│  - CollectionBox<String> for data           │
│  - CollectionBox<String> for metadata       │
│  - Raw string storage only                  │
└─────────────────────────────────────────────┘
```

## Layer Details

### 1. HHive (API Layer)
**Location**: `lib/core/hive.dart`

**Responsibilities**:
- User-facing API (get, put, delete, pop, clear, getMeta, putMeta)
- Emit action events (valueRead, valueWrite, metadataRead, metadataWrite, onDelete, onClear)
- Handle control flow exceptions (`HHCtrlException`)
- Create context objects (`HHCtx`)
- Factory pattern for singleton instances per environment

**Key Pattern**:
```dart
static Future<dynamic> staticGet(HHPayload payload) async {
  final ctx = HHCtx(payload);
  return await ctx.control.emit(
    TriggerType.valueRead.name,  // ← Action event HERE
    action: (ctx) async {
      return await ctx.access.storeGet(ctx.payload.key!);
    },
    handleCtrlException: true,
  );
}
```

**Critical**: This is the ONLY place where action events are emitted.

### 2. HHCtxControl (Hook Execution Engine)
**Location**: `lib/core/ctx.dart`

**Responsibilities**:
- Execute hooks in correct order (pre → action → post)
- Handle `HHCtrlException` for control flow
- Manage batch skipping (f_skip between batches)
- Provide `breakEarly()` helper for hooks

**Execution Flow**:
```dart
Future<dynamic> emit(String eventName, {...}) async {
  // 1. Pre-hooks
  for (var hook in preHooks) {
    await invoke(hook.action, handleCtrlException);
  }
  
  // 2. Main action (if not skipped)
  if (action != null && !skipNextBatch) {
    result = await invoke(action, handleCtrlException);
  }
  
  // 3. Post-hooks
  for (var hook in postHooks) {
    await invoke(hook.action, handleCtrlException);
  }
  
  return result;
}
```

**Control Flow Handling**:
- `f_continue`: Continue to next hook
- `f_skip`: Skip next batch (pre→action or action→post)
- `f_break`: Break out, return value
- `f_delete`: Delete key and return
- `f_pop`: Pop key (get+delete) and return
- `f_panic`: Throw runtime exception

### 3. HHCtxDirectAccess (Data Access Layer)
**Location**: `lib/core/ctx.dart`

**Responsibilities**:
- Direct Hive box access
- Apply serialization hooks (for store values)
- Apply terminal hooks (for both store and metadata)
- Update payload before calling hooks
- **NEVER emit action events**

**Store Value Pattern**:
```dart
Future<dynamic> storeGet(String key) async {
  final box = await store;
  final rawResult = await box.get(key);
  
  // Terminal deserialization
  String valueStr = await ctx.control.emit(
    TriggerType.onValueTDeserialize.name,  // Serialization event
    action: (ctx) async { /* terminal hooks */ },
  );
  
  // Application serialization
  final value = await ctx.control.emit(
    TriggerType.onValueDeserialize.name,   // Serialization event
    action: (ctx) async { /* serialization hooks */ },
  );
  
  return value;
}
```

**Metadata Pattern** (simpler - no SerializationHooks):
```dart
Future<Map<String, dynamic>?> metaGet(String key) async {
  final box = await meta;
  final rawResult = await box.get(key);
  
  // Terminal deserialization only
  String metaStr = await ctx.control.emit(
    TriggerType.onMetaTDeserialize.name,
    action: (ctx) async { /* terminal hooks */ },
  );
  
  // Direct JSON decode - no serialization hooks
  return jsonDecode(metaStr) as Map<String, dynamic>;
}
```

**Critical Pattern**: Update payload before calling hooks:
```dart
ctx.payload = ctx.payload.copyWith(value: result);
result = await hook.deserialize(ctx);
```

### 4. Configuration System
**Location**: `lib/core/config.dart`

**Pattern**: Mutable builder → Immutable runtime
```
HHConfig (mutable)
  - Install/uninstall plugins
  - Add/remove hooks
  - Call .finalize()
    ↓
HHImmutableConfig (immutable)
  - Singleton per environment
  - Organized hook maps (preActionHooks, postActionHooks)
  - Sorted by priority
  - Cannot modify
```

**Hook Organization**:
- Hooks grouped by event name
- Pre/post separation
- Sorted by priority (higher = earlier)
- Sets deduplicated, then converted to lists

## Why This Architecture Works

### Prevents Infinite Loops
By separating action events (API layer) from serialization events (access layer), hooks can safely call `hive.get()` without triggering `valueRead` events in the access layer.

### Clear Separation of Concerns
- API: User interface and high-level events
- Control: Hook orchestration
- Access: Storage with transformations
- Storage: Raw persistence

### Safe Recursion
Hooks can call any HiveHook method because:
1. Hook executes in API layer context
2. Hook calls `hive.get()`
3. API layer emits `valueRead` (different instance, different execution)
4. Access layer called, applies serialization (no action events)
5. No recursion back to original hook

### Immutable Configuration
Once finalized, configuration cannot change. This ensures:
- Thread-safe access
- Predictable behavior
- No runtime surprises
- Clear lifecycle (build → finalize → use)
