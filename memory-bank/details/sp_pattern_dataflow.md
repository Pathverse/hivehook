# Data Flow Patterns - Detailed

## Write Operation (Store Value)

```
User calls: hive.put('key', 'value')
  ↓
HHive.put() creates payload
  ↓
HHive.staticPut(payload)
  ↓ emit(valueWrite) ← ACTION EVENT
  ↓
PRE-ACTION HOOKS
  ├─→ Hook 1 (priority 100)
  ├─→ Hook 2 (priority 50)
  └─→ Hook 3 (priority 10)
  ↓
MAIN ACTION: ctx.access.storePut(key, value)
  ↓
HHCtxDirectAccess.storePut()
  ↓ emit(onValueSerialize) ← SERIALIZATION EVENT
  ↓
APPLICATION SERIALIZATION HOOKS
  ├─→ Hook checks canHandle?
  ├─→ ctx.payload = ctx.payload.copyWith(value: result)
  ├─→ result = await hook.serialize(ctx)
  └─→ (repeat for each hook)
  ↓
  ↓ emit(onValueTSerialize) ← TERMINAL SERIALIZATION EVENT
  ↓
TERMINAL SERIALIZATION HOOKS
  ├─→ Compression hook
  ├─→ Encryption hook
  └─→ Base64 encoding hook
  ↓
Hive box.put(key, finalSerializedValue)
  ↓
POST-ACTION HOOKS
  ├─→ Hook 1 (priority 100)
  ├─→ Hook 2 (priority 50)
  └─→ Hook 3 (priority 10)
  ↓
Return to user
```

## Read Operation (Store Value)

```
User calls: hive.get('key')
  ↓
HHive.get() creates payload
  ↓
HHive.staticGet(payload)
  ↓ emit(valueRead) ← ACTION EVENT
  ↓
PRE-ACTION HOOKS
  ├─→ Cache check hook (might breakEarly)
  ├─→ Validation hook
  └─→ Logging hook
  ↓
MAIN ACTION: ctx.access.storeGet(key)
  ↓
HHCtxDirectAccess.storeGet()
  ↓
Hive box.get(key) → rawSerializedValue
  ↓ emit(onValueTDeserialize) ← TERMINAL DESERIALIZATION EVENT
  ↓
TERMINAL DESERIALIZATION HOOKS (reverse order)
  ├─→ Base64 decode hook
  ├─→ Decryption hook
  └─→ Decompression hook
  ↓
  ↓ emit(onValueDeserialize) ← SERIALIZATION EVENT
  ↓
APPLICATION DESERIALIZATION HOOKS
  ├─→ Hook checks canHandle?
  ├─→ ctx.payload = ctx.payload.copyWith(value: result)
  ├─→ result = await hook.deserialize(ctx)
  └─→ (repeat for each hook)
  ↓
Return deserialized value
  ↓
POST-ACTION HOOKS
  ├─→ Transform hook
  ├─→ Cache store hook
  └─→ Metrics hook
  ↓
Return to user
```

## Metadata Write Operation

```
User calls: hive.putMeta('key', {'field': 'value'})
  ↓
HHive.putMeta() creates payload
  ↓
HHive.staticPutMeta(payload)
  ↓ emit(metadataWrite) ← ACTION EVENT
  ↓
PRE-ACTION HOOKS
  ├─→ Validation hook
  └─→ Logging hook
  ↓
MAIN ACTION: ctx.access.metaPut(key, metadata)
  ↓
HHCtxDirectAccess.metaPut()
  ↓
JSON.encode(metadata) → JSON string
  ↓ emit(onMetaTSerialize) ← TERMINAL SERIALIZATION EVENT
  ↓
TERMINAL SERIALIZATION HOOKS ONLY
  ├─→ Encryption hook
  └─→ Compression hook
  ↓
Hive metaBox.put(key, finalSerializedMeta)
  ↓
POST-ACTION HOOKS
  ├─→ Audit log hook
  └─→ Sync hook
  ↓
Return to user

NOTE: No SerializationHooks for metadata - always Map<String, dynamic>
```

## Metadata Read Operation

```
User calls: hive.getMeta('key')
  ↓
HHive.getMeta() creates payload
  ↓
HHive.staticGetMeta(payload)
  ↓ emit(metadataRead) ← ACTION EVENT
  ↓
PRE-ACTION HOOKS
  └─→ Access control hook
  ↓
MAIN ACTION: ctx.access.metaGet(key)
  ↓
HHCtxDirectAccess.metaGet()
  ↓
Hive metaBox.get(key) → rawSerializedMeta
  �� emit(onMetaTDeserialize) ← TERMINAL DESERIALIZATION EVENT
  ↓
TERMINAL DESERIALIZATION HOOKS ONLY
  ├─→ Decompression hook
  └─→ Decryption hook
  ↓
JSON.decode(metaStr) → Map<String, dynamic>
  ↓
Return metadata map
  ↓
POST-ACTION HOOKS
  └─→ Cache hook
  ↓
Return to user

NOTE: No SerializationHooks for metadata - always Map<String, dynamic>
```

## Control Flow Example

```
User calls: hive.get('key')
  ↓
PRE-ACTION HOOK: Cache check
  ↓
  Cache hit? → ctx.control.breakEarly(cachedValue)
  ↓
  THROWS HHCtrlException(nextPhase: f_break, returnValue: cachedValue)
  ↓
HHCtxControl catches exception
  ↓
  Checks nextPhase == f_break
  ↓
  Returns returnValue immediately
  ↓
SKIPS: Main action, post-hooks
  ↓
Return cachedValue to user
```

## Hook Priority Example

```
Config has 3 pre-write hooks:
- Hook A (priority: 10)
- Hook B (priority: 100)
- Hook C (priority: 50)

Execution order: B (100) → C (50) → A (10)

HHImmutableConfig factory sorts on creation:
1. Groups hooks by event name
2. Separates pre/post
3. Sorts by priority (higher first)
4. Stores in immutable maps
```

## Payload Updates in Serialization

```
Initial: ctx.payload.value = "originalValue"
  ↓
Hook 1: JSON serialization
  ctx.payload = ctx.payload.copyWith(value: result)
  → ctx.payload.value = '{"data":"originalValue"}'
  ↓
Hook 2: Compression
  ctx.payload = ctx.payload.copyWith(value: result)
  → ctx.payload.value = 'compressed_json_bytes'
  ↓
Hook 3: Base64 encoding
  ctx.payload = ctx.payload.copyWith(value: result)
  → ctx.payload.value = 'YmFzZTY0X2VuY29kZWQ='
  ↓
Final value stored in Hive
```

Each hook sees the transformation from the previous hook in `ctx.payload.value`.
