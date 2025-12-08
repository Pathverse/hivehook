# Future Feature: Batch Operations Design

## Goal
Execute multiple operations efficiently while maintaining hook system integrity

## Current Progress
- `HHFullPayload` class created for individual batch items
- `HHBatchPayload` class created for batch container
- Design considerations identified (Nov 28, 2025)

## Design Decisions Needed

### 1. Hook Execution Strategy - Hybrid Approach Recommended
- Emit `batchStart` event before batch execution
- Execute individual operations normally (each emits own events)
- Share context across batch via `ctx.data.runtimeData['batchItems']`
- Emit `batchEnd` event after batch completion
- Hooks can detect batch mode and optimize if needed

### 2. Context Lifecycle
**Current**: Context created per operation, destroyed after completion
**Batch needs**: Context survives across all batch items
**Solution**: Create one context, pass through all operations, store batch state in `ctx.data.runtimeData`

### 3. Return Values
- Need `HHBatchResult` class with `List<dynamic> results` and `List<Exception?> errors`
- Support mixed operations (gets + puts) in same batch

### 4. Type Safety
- Use factory constructors: `HHFullPayload.get()`, `.put()`, `.delete()`, `.clear()`
- Prevents invalid field combinations

### 5. API Surface
**Options**: Standalone `batch.execute()` vs `hive.batch([...])`
**Recommendation**: Through HHive to maintain architectural consistency

## Implementation Checklist

When ready to implement:
- [ ] Add `batchStart` and `batchEnd` to `TriggerType` enum
- [ ] Implement `HHBatchResult` class
- [ ] Add factory constructors to `HHFullPayload`
- [ ] Implement context sharing mechanism
- [ ] Add `batch()` method to HHive API
- [ ] Write batch operation tests
- [ ] Document batch-aware hook patterns
- [ ] Consider adding `ctx.isBatch` boolean flag

## Key Insight
Hybrid approach maintains backward compatibility while enabling batch optimizations for hooks that care about batches.
