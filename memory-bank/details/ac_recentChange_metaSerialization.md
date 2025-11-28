# Metadata Serialization Bug Fix (Nov 27, 2025)

## Problem
Metadata is always `Map<String, dynamic>` (fixed structure), yet system was applying `SerializationHook` transformations. This was pointless since metadata is directly JSON encoded/decoded - any custom hook would just transform JSON → JSON.

## Solution
**Removed**:
- `metaSerializationHooks` field from `HHImmutableConfig`
- `SerializationHook` loop from `metaGet()` and `metaPut()`
- `forMeta` flag from `SerializationHook` class

**Kept**:
- `TerminalSerializationHook` for metadata (encryption/compression on JSON string)
- Direct JSON encode/decode

## Files Modified
1. `lib/core/config.dart`: Removed `metaSerializationHooks` field and separation logic
2. `lib/core/ctx.dart`: Simplified `metaGet()`/`metaPut()` to JSON + terminal hooks only
3. `lib/hooks/serialization_hook.dart`: Removed `forMeta` parameter

## Why This Makes Sense
- Metadata structure is fixed: `Map<String, dynamic>`
- JSON encode/decode is deterministic
- SerializationHooks are for **value type transformations**, not infrastructure
- Terminal hooks still enable encryption/compression of the JSON string

## Impact
- Cleaner codebase with less abstraction overhead
- More efficient metadata operations
- All 42 tests passing
