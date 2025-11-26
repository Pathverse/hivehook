# Plugin Flow Documentation

This document explains how plugins hook into the HiveHook execution flow, using the TTL and LRU template plugins as examples.

## Table of Contents
- [Overview](#overview)
- [TTL Plugin Flow](#ttl-plugin-flow)
- [LRU Plugin Flow](#lru-plugin-flow)
- [Priority System](#priority-system)
- [Key Patterns](#key-patterns)

## Overview

Plugins use **action hooks** with **latches** to intercept operations at specific points in the execution flow. Hooks can be:
- **Pre-hooks**: Execute BEFORE the main operation (can modify payload, prevent operation)
- **Post-hooks**: Execute AFTER the main operation (can modify result, trigger side effects)

Both TTL and LRU plugins use pre-hooks because they need to:
- **Modify data** before it's written (TTL timestamps, LRU access times)
- **Prevent operations** (TTL expires data, LRU evicts items)

## TTL Plugin Flow

The TTL (Time-To-Live) plugin automatically expires data after a specified time period.

### Write Operation: `hive.put('key', 'value')`

```
┌─────────────────────────────────────────────────────────────┐
│ User Code                                                   │
│ await hive.put('key', 'value');                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ HHive.staticPut()                                           │
│ Emits "valueWrite" event                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 🪝 TTL PRE-HOOK (priority: 100)                            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 1. Read existing metadata from ctx.payload.metadata    │ │
│ │ 2. Create mutable copy: Map.from(existingMeta)         │ │
│ │ 3. Add 'ttl': '3600' (if not already specified)        │ │
│ │ 4. Add 'created_at': <current timestamp in ms>         │ │
│ │ 5. Update payload: ctx.payload.copyWith(metadata: meta)│ │
│ └─────────────────────────────────────────────────────────┘ │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Main Action                                                 │
│ ctx.access.storePut(key, value) → Writes to Hive          │
│ Metadata stored alongside value                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Returns to user                                             │
└─────────────────────────────────────────────────────────────┘
```

**Code Reference** (`lib/templates/ttl_plugin.dart`):
```dart
HActionHook(
  latches: [
    HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 100),
  ],
  action: (ctx) async {
    final existingMeta = ctx.payload.metadata ?? {};
    final meta = Map<String, dynamic>.from(existingMeta);
    
    if (!meta.containsKey('ttl')) {
      meta['ttl'] = defaultTTLSeconds.toString();
    }
    
    meta['created_at'] = DateTime.now().millisecondsSinceEpoch.toString();
    ctx.payload = ctx.payload.copyWith(metadata: meta);
  },
)
```

### Read Operation: `hive.get('key')`

```
┌─────────────────────────────────────────────────────────────┐
│ User Code                                                   │
│ final value = await hive.get('key');                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ HHive.staticGet()                                           │
│ Emits "valueRead" event                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 🪝 TTL PRE-HOOK (priority: 100)                            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 1. Load metadata: ctx.access.metaGet(key)              │ │
│ │ 2. Extract ttl and created_at timestamps               │ │
│ │ 3. Calculate expiration: now > created_at + (ttl*1000)?│ │
│ │                                                         │ │
│ │ If EXPIRED:                                             │ │
│ │   ├─ Delete value: ctx.access.storeDelete(key)        │ │
│ │   ├─ Delete metadata: ctx.access.metaDelete(key)      │ │
│ │   └─ Throw HHCtrlException(                           │ │
│ │         nextPhase: NextPhase.f_break,                  │ │
│ │         returnValue: null                              │ │
│ │       )                                                 │ │
│ │       → STOPS EXECUTION, returns null immediately      │ │
│ │                                                         │ │
│ │ If NOT EXPIRED:                                         │ │
│ │   └─ Continue to main action                           │ │
│ └─────────────────────────────────────────────────────────┘ │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Main Action (only if NOT expired)                          │
│ ctx.access.storeGet(key) → Reads from Hive                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Returns value or null to user                               │
└─────────────────────────────────────────────────────────────┘
```

**Code Reference**:
```dart
HActionHook(
  latches: [
    HHLatch.pre(triggerType: TriggerType.valueRead, priority: 100),
  ],
  action: (ctx) async {
    final meta = await ctx.access.metaGet(ctx.payload.key!);
    if (meta == null) return; // No metadata, allow read
    
    final ttl = int.tryParse(meta['ttl']);
    final createdAt = int.tryParse(meta['created_at']);
    
    if (ttl != null && createdAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = createdAt + (ttl * 1000);
      
      if (now > expiresAt) {
        await ctx.access.storeDelete(ctx.payload.key!);
        await ctx.access.metaDelete(ctx.payload.key!);
        
        throw HHCtrlException(
          nextPhase: NextPhase.f_break,
          returnValue: null,
          runtimeMeta: {'reason': 'ttl_expired'},
        );
      }
    }
  },
)
```

**Key Insight**: TTL uses a pre-hook to check expiration BEFORE reading from storage, preventing expired data from ever being accessed.

---

## LRU Plugin Flow

The LRU (Least Recently Used) plugin maintains a cache with a maximum size, evicting the least recently used items when full.

### Read Operation: `hive.get('key1')`

```
┌─────────────────────────────────────────────────────────────┐
│ User Code                                                   │
│ final value = await hive.get('key1');                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ HHive.staticGet()                                           │
│ Emits "valueRead" event                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 🪝 LRU PRE-HOOK (priority: 95)                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 1. Load existing metadata: ctx.access.metaGet('key1')  │ │
│ │ 2. Create mutable copy                                  │ │
│ │ 3. Update 'last_accessed': <current timestamp>         │ │
│ │ 4. Save: ctx.access.metaPut('key1', meta)              │ │
│ │                                                         │ │
│ │ Purpose: Mark this key as recently used                │ │
│ └─────────────────────────────────────────────────────────┘ │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Main Action                                                 │
│ ctx.access.storeGet('key1') → Reads from Hive             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Returns value to user                                       │
└─────────────────────────────────────────────────────────────┘
```

**Code Reference** (`lib/templates/lru_plugin.dart`):
```dart
HActionHook(
  latches: [
    HHLatch.pre(
      triggerType: TriggerType.valueRead,
      priority: 95, // Higher priority than write check
    ),
  ],
  action: (ctx) async {
    final existingMeta = await ctx.access.metaGet(ctx.payload.key!) ?? {};
    final meta = Map<String, dynamic>.from(existingMeta);
    meta['last_accessed'] = DateTime.now().millisecondsSinceEpoch.toString();
    
    await ctx.access.metaPut(ctx.payload.key!, meta);
  },
)
```

### Write Operation: `hive.put('key4', 'value4')`

```
┌─────────────────────────────────────────────────────────────┐
│ User Code                                                   │
│ await hive.put('key4', 'value4');                          │
│ (Cache currently has: key1, key2, key3 - maxSize is 3)    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ HHive.staticPut()                                           │
│ Emits "valueWrite" event                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 🪝 LRU PRE-HOOK (priority: 90)                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 1. Add 'last_accessed' to payload metadata             │ │
│ │                                                         │ │
│ │ 2. Load cache index from special metadata key:         │ │
│ │    ctx.access.metaGet('_lru_cache_keys')               │ │
│ │    → Contains: "key1,key2,key3"                        │ │
│ │                                                         │ │
│ │ 3. Parse into list: ['key1', 'key2', 'key3']          │ │
│ │                                                         │ │
│ │ 4. Check if key4 exists in cache                       │ │
│ │    → No, it's a NEW key                                │ │
│ │                                                         │ │
│ │ 5. Cache full? (3 >= 3)                                │ │
│ │    → Yes! Need to evict                                │ │
│ │                                                         │ │
│ │ 6. Find LRU item by scanning all keys:                │ │
│ │    For each key in ['key1', 'key2', 'key3']:          │ │
│ │      - Load metadata                                    │ │
│ │      - Read 'last_accessed' timestamp                  │ │
│ │      - Track oldest: key2 = 1732000000                │ │
│ │                      key1 = 1732100000 (recently used!)│ │
│ │                      key3 = 1732050000                 │ │
│ │    → key2 is the LRU item                              │ │
│ │                                                         │ │
│ │ 7. Evict key2:                                         │ │
│ │    ├─ ctx.access.storeDelete('key2')                  │ │
│ │    ├─ ctx.access.metaDelete('key2')                   │ │
│ │    └─ Remove from cache list                           │ │
│ │                                                         │ │
│ │ 8. Add key4 to cache list: ['key1', 'key3', 'key4']  │ │
│ │                                                         │ │
│ │ 9. Update cache index:                                 │ │
│ │    ctx.access.metaPut('_lru_cache_keys',               │ │
│ │                       {'keys': 'key1,key3,key4'})     │ │
│ └─────────────────────────────────────────────────────────┘ │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Main Action                                                 │
│ ctx.access.storePut('key4', 'value4') → Writes to Hive    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ Returns to user                                             │
│ Cache now contains: key1, key3, key4 (key2 evicted)       │
└─────────────────────────────────────────────────────────────┘
```

**Code Reference**:
```dart
HActionHook(
  latches: [
    HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 90),
  ],
  action: (ctx) async {
    // Set access time for new entry
    final existingMeta = ctx.payload.metadata ?? {};
    final meta = Map<String, dynamic>.from(existingMeta);
    meta['last_accessed'] = DateTime.now().millisecondsSinceEpoch.toString();
    ctx.payload = ctx.payload.copyWith(metadata: meta);
    
    // Get cache index
    final cacheIndexMeta = await ctx.access.metaGet('_lru_cache_keys');
    final keysString = cacheIndexMeta?['keys'] as String?;
    var cacheKeys = keysString?.split(',').where((k) => k.isNotEmpty).toList() 
                    ?? <String>[];
    
    // Check if key already exists
    final keyExists = cacheKeys.contains(ctx.payload.key);
    if (keyExists) {
      cacheKeys.remove(ctx.payload.key);
    }
    
    // Evict if adding new key and cache is full
    if (!keyExists && cacheKeys.length >= maxSize) {
      String? lruKey;
      int? oldestAccess;
      
      for (final key in cacheKeys) {
        final itemMeta = await ctx.access.metaGet(key);
        final lastAccessed = int.tryParse(itemMeta?['last_accessed'] ?? '');
        
        if (lastAccessed != null && 
            (oldestAccess == null || lastAccessed < oldestAccess)) {
          oldestAccess = lastAccessed;
          lruKey = key;
        }
      }
      
      if (lruKey != null) {
        await ctx.access.storeDelete(lruKey);
        await ctx.access.metaDelete(lruKey);
        cacheKeys.remove(lruKey);
      }
    }
    
    // Add current key to cache
    cacheKeys.add(ctx.payload.key!);
    await ctx.access.metaPut('_lru_cache_keys', {'keys': cacheKeys.join(',')});
  },
)
```

**Key Insight**: LRU uses TWO pre-hooks - one on read (priority 95) to update access times, and one on write (priority 90) to handle eviction. The higher priority on read ensures recently accessed items have updated timestamps before any eviction logic runs.

---

## Priority System

Hooks execute in **priority order** (higher number = runs first):

### Read Operation Flow

```
User: hive.get('key1')
  ↓
Event: "valueRead"
  ↓
Priority 100: TTL read hook (check expiration)
  ↓
Priority 95:  LRU read hook (update access time)
  ↓
Main Action:  ctx.access.storeGet() (read from storage)
  ↓
Return value
```

### Write Operation Flow

```
User: hive.put('key4', 'value4')
  ↓
Event: "valueWrite"
  ↓
Priority 100: TTL write hook (add timestamps)
  ↓
Priority 90:  LRU write hook (eviction check)
  ↓
Main Action:  ctx.access.storePut() (write to storage)
  ↓
Return
```

### Why Priority Matters

**Scenario**: User calls `hive.get('key1')` then `hive.put('key4', 'value4')`

```
Step 1: hive.get('key1')
  → LRU hook (priority 95) updates key1's last_accessed to NOW
  → key1 becomes the most recently used item

Step 2: hive.put('key4', 'value4')  
  → LRU hook (priority 90) checks which key to evict
  → Scans last_accessed timestamps
  → key1 has FRESH timestamp from Step 1
  → key2 has oldest timestamp
  → key2 gets evicted, key1 stays!
```

If LRU read hook had lower priority (e.g., 80), the write hook might run first and evict based on stale timestamps.

---

## Key Patterns

### 1. Pre-hooks for Modification

Both plugins use **pre-hooks** to intercept operations BEFORE they execute:

```dart
// Pre-hook - runs BEFORE main action
HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 100)

// Post-hook - runs AFTER main action  
HHLatch(triggerType: TriggerType.valueWrite, isPost: true, priority: 100)
```

**Why pre-hooks?**
- Can **modify payload** before writing (add metadata)
- Can **prevent operation** entirely (break early for expired data)
- Can **prepare state** before main action (evict before writing)

### 2. Metadata for State Storage

Plugins store state in metadata:

```dart
// TTL metadata
{
  'ttl': '3600',           // Time to live in seconds
  'created_at': '1732...'  // Creation timestamp in milliseconds
}

// LRU metadata
{
  'last_accessed': '1732...' // Last access timestamp
}

// LRU cache index (special metadata key)
'_lru_cache_keys' → {'keys': 'key1,key2,key3'}
```

**Advantages**:
- Survives restarts (persisted with data)
- Per-key tracking (each item has own metadata)
- No external state management needed

### 3. Direct Access via ctx.access

Plugins use `ctx.access` methods to avoid triggering more hooks:

```dart
// ❌ BAD: Would trigger hooks again (infinite loop risk)
await hive.get('key')

// ✅ GOOD: Direct access, no hooks triggered
await ctx.access.metaGet('key')
await ctx.access.storeDelete('key')
```

**Available methods**:
- `storeGet(key)` - Read value directly
- `storePut(key, value)` - Write value directly  
- `storeDelete(key)` - Delete value directly
- `metaGet(key)` - Read metadata directly
- `metaPut(key, meta)` - Write metadata directly
- `metaDelete(key)` - Delete metadata directly

### 4. Control Flow with HHCtrlException

Hooks can control execution flow by throwing exceptions:

```dart
// Break early and return a value
throw HHCtrlException(
  nextPhase: NextPhase.f_break,
  returnValue: null,
  runtimeMeta: {'reason': 'ttl_expired'},
);
```

**Available control flow options**:
- `NextPhase.f_break` - Stop execution, return value immediately
- `NextPhase.f_skip` - Skip remaining hooks in current batch
- `NextPhase.f_continue` - Continue to next hook (default)
- `NextPhase.f_delete` - Delete the key and stop
- `NextPhase.f_pop` - Return value and delete key
- `NextPhase.f_panic` - Throw error to user

### 5. Priority-Based Coordination

Plugins coordinate using priorities:

```dart
// LRU read hook - runs FIRST (priority 95)
// Updates access times before any eviction checks
HHLatch.pre(triggerType: TriggerType.valueRead, priority: 95)

// LRU write hook - runs SECOND (priority 90)  
// Uses updated access times from read hook
HHLatch.pre(triggerType: TriggerType.valueWrite, priority: 90)
```

**Best practices**:
- Higher priority (90-100): System plugins like caching, expiration
- Medium priority (50-89): Business logic, validation
- Lower priority (1-49): Logging, metrics, auditing
- Multiple plugins can use same priority (order undefined within same priority)

---

## Complete Example

Here's a complete example showing both plugins working together:

```dart
// Setup
final ttlPlugin = createTTLPlugin(defaultTTLSeconds: 60);
final lruPlugin = createLRUPlugin(maxSize: 3);

final config = HHConfig(env: 'app', usesMeta: true);
config.installPlugin(ttlPlugin);
config.installPlugin(lruPlugin);

final hive = HHive(config: config.finalize());

// Usage
await hive.put('key1', 'value1');  // Adds TTL + LRU tracking
await hive.put('key2', 'value2');
await hive.put('key3', 'value3');  // Cache full (3/3)

await hive.get('key1');  // LRU updates key1 access time

await hive.put('key4', 'value4');  // LRU evicts key2 (least recently used)

// After 61 seconds
await hive.get('key1');  // TTL returns null (expired)

// Current state:
// key1: deleted (expired by TTL)
// key2: deleted (evicted by LRU)  
// key3: exists (not accessed, but not evicted yet)
// key4: exists (newest)
```

---

## Creating Your Own Plugin

Use these template plugins as examples:

1. **Determine hook points**: Pre or post? Read or write?
2. **Choose priorities**: Higher = runs first (90-100 for system plugins)
3. **Store state in metadata**: Survives restarts, per-key tracking
4. **Use ctx.access for queries**: Avoid infinite loops
5. **Control flow with exceptions**: Break early, skip, delete, etc.

Example structure:

```dart
HHPlugin createMyPlugin({/* params */}) {
  return HHPlugin(
    actionHooks: [
      HActionHook(
        latches: [
          HHLatch.pre(
            triggerType: TriggerType.valueWrite,
            priority: 85,
          ),
        ],
        action: (ctx) async {
          // Your logic here
          // - Read: ctx.access.metaGet()
          // - Modify: ctx.payload = ctx.payload.copyWith(...)
          // - Control: throw HHCtrlException(...)
        },
      ),
    ],
  );
}
```

See `lib/templates/` for complete working examples.
