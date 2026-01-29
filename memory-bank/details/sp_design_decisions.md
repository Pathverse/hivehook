# Design Decisions

Track design decisions for hivehook integration with hihook.

> **Note**: `hivehook2` is folder name. Package remains `hivehook`.

---

# Upstream Decisions (U-series)

These affect hihook directly. Must resolve before Part 2.

---

## U1: Plugin Storage Strategy

**Status**: Decided ✅

**Question**: How do TTL/LRU plugins access storage in hihook (which is storage-agnostic)?

**Decision**: Option A' - Metadata via Context Data

### The Contract

Plugins operate on `ctx.data['meta']`. Consumer fulfills:

| Responsibility | Who | How |
|----------------|-----|-----|
| Pre-load metadata | Consumer (hivehook) | Before `emit()`, set `ctx.data['meta']` |
| Check/modify metadata | Plugin (hihook) | Via conditions and hooks |
| Persist metadata | Consumer (hivehook) | After `emit()`, if `wasWritten('meta')` |
| Handle HiDelete | Consumer (hivehook) | Delete from storage |

### Example Flow

```dart
// hivehook (consumer):
final meta = await metaBox.get(key);
final ctx = HiContext(event: 'read', payload: payload);
ctx.data['meta'] = meta ?? {};

final result = await engine.emit('read', payload);

// Persist if modified
if (ctx.dataTracked.wasWritten('meta')) {
  await metaBox.put(key, ctx.data['meta']);
}

// Handle delete
if (result is HiDelete) {
  await box.delete(key);
  await metaBox.delete(key);
}
```

```dart
// hihook (TTL plugin):
final isNotExpired = HiCond(
  name: 'ttl:notExpired',
  predicate: (_, data) => !_isExpired(data['meta']),
  isStable: false,
);

HiHook(
  events: ['read'],
  conditions: [~isNotExpired],  // IS expired
  handler: (ctx) => HiDelete,
)
```

### Why This Works

- Plugins are **complete in logic** (conditions, hooks, results)
- Consumer fulfills **storage contract** (load, persist, delete)
- Uses existing `ctx.dataTracked.wasWritten()` for change detection
- No changes needed to hihook core

---

## U2: Web Debug as Plugin

**Status**: Decided ✅

**Question**: Upstream web_debug to hihook or keep in hivehook?

**Decision**: Keep in hivehook only (not upstreamed)

**Rationale**:
- Platform-specific (requires conditional imports at compile time)
- Debug-only feature, not business logic
- Tightly coupled to Hive storage keys (`{env}::{key}`)

---

## U3: Plugin Meta Dependency

**Status**: Decided ✅

**Question**: What if consumer doesn't provide `ctx.data['meta']`?

**Decision**: Graceful handling - no meta = no enforcement (plugin becomes no-op)

```dart
// TTL condition - handles missing meta gracefully
HiCond(
  name: 'ttl:notExpired',
  predicate: (_, data) {
    final meta = data['meta'] as Map<String, dynamic>?;
    if (meta == null) return true;  // No meta = allow (no TTL)
    final created = meta['created_at'] as int?;
    final ttl = meta['ttl_seconds'] as int?;
    if (created == null || ttl == null) return true;  // Incomplete = allow
    return DateTime.now().millisecondsSinceEpoch < created + (ttl * 1000);
  },
  isStable: false,
)
```

**Behavior**:
| Scenario | Result |
|----------|--------|
| No `ctx.data['meta']` | Plugin no-op (allows read/write) |
| Meta exists, no TTL fields | Plugin no-op |
| Meta exists with TTL fields | TTL enforced |

---

# Integration Decisions (D-series)

**Status**: All Deferred until Part 1 (upstream) complete.

| # | Topic | Notes |
|---|-------|-------|
| D1 | HHPayload ↔ HiPayload | Extend, wrap, or separate? |
| D2 | Engine ownership | Per-HHive, shared, or static? |
| D3 | HActionHook translation | How to convert latches? |
| D4 | Serialization strategy | Keep types or use HiHooks? |
| D5 | Control flow mapping | NextPhase → HiResult (f_pop?) |
| D6 | HHLatch translation | isPost → HiPhase? |

---

## Summary

| # | Topic | Status | Decision |
|---|-------|--------|----------|
| U1 | Plugin storage strategy | ✅ Decided | Metadata via ctx.data |
| U2 | Web debug as plugin | ✅ Decided | Keep in hivehook only |
| U3 | Plugin meta dependency | ✅ Decided | Graceful no-op if missing |
| D1-D6 | Integration decisions | Deferred | - |
