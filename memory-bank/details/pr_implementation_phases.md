# Implementation Phases

## Overview

**Two-part implementation:**
1. **Part 1**: Upstream plugins to hihook (TTL, LRU, Base64)
2. **Part 2**: Transition hivehook to use hihook + simple hive_ce

> **Note**: `hivehook2` is folder name. Package remains `hivehook`.

## Workflow (Per Phase)

```
┌─────────────────────────────────────────────────┐
│ 1. Discuss scope and open decisions            │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 2. Create test files (TDD)                     │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 3. Implement source files                      │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│ 4. Run tests, update memory bank               │
└─────────────────────────────────────────────────┘
```

---

# Part 1: Upstream Plugins to hihook

## U-Phase 0: Setup

**Goal**: Create plugins folder in hihook

| Task | File |
|------|------|
| Create folder | `hihook/lib/src/plugins/` |
| Export barrel | `hihook/lib/src/plugins/plugins.dart` |
| Update main barrel | `hihook/lib/hihook.dart` |

---

## U-Phase 1: Base64 Plugin

**Goal**: Simple encoding plugin (no storage needed)

| Source File | Test File |
|-------------|-----------|
| `plugins/base64.dart` | `test/plugins/pl_base64_test.dart` |

**Scope**:
- Hook on `valueWrite` (pre) - encode value to base64
- Hook on `valueRead` (post) - decode value from base64
- No storage access needed - pure value transform

---

## U-Phase 2: Storage Abstraction (if needed)

**Goal**: Define how plugins access storage

**Decision U1 must be resolved first.**

Options:
- A) Metadata-only (plugins set metadata, storage reads it)
- B) Abstract storage interface
- C) Context callbacks

---

## U-Phase 3: TTL Plugin

**Goal**: Time-to-live expiration (storage-agnostic)

| Source File | Test File |
|-------------|-----------|
| `plugins/ttl.dart` | `test/plugins/pl_ttl_test.dart` |

**Depends on**: U-Phase 2 (storage strategy)

---

## U-Phase 4: LRU Plugin

**Goal**: Least-recently-used cache eviction

| Source File | Test File |
|-------------|-----------|
| `plugins/lru.dart` | `test/plugins/pl_lru_test.dart` |

**Depends on**: U-Phase 2 (storage strategy)

---

# Part 2: hivehook Transition

## Phase 0: Setup

**Goal**: Project structure and dependencies

| Task | File |
|------|------|
| Update pubspec | `pubspec.yaml` - add hihook dep |
| Create folders | `lib/`, `test/` structure |
| Barrel export | `lib/hivehook.dart` |

---

## Phase 1: Core Layer

**Goal**: Base types and Hive initialization

| Source File | Test Files |
|-------------|------------|
| `core/base.dart` | `cr_base_test.dart` |
| `core/hive.dart` | `cr_hive_test.dart` |

**Scope**:
- HHiveCore (Hive BoxCollection init)
- HHive (CRUD using HiEngine.emit())

---

## Phase 2: Storage Hooks

**Goal**: Hooks that persist to Hive

| Source File | Test Files |
|-------------|------------|
| `hooks/storage.dart` | `hk_storage_test.dart` |

**Scope**:
- Store hooks (storeGet, storePut, storeDelete)
- Meta hooks (metaGet, metaPut, metaDelete)
- Serialization (JSON encode/decode for Hive String storage)

---

## Phase 3: Integration

**Goal**: Full integration tests

| Test Files |
|------------|
| `in_crud_test.dart` |
| `in_ttl_test.dart` |
| `in_lru_test.dart` |

---

## Status

### Part 1: Upstream (hihook)

| Phase | Task | Status |
|-------|------|--------|
| U-0 | Setup plugins folder | 🔲 |
| U-1 | Base64 plugin | 🔲 |
| U-2 | Storage abstraction | 🔲 (needs U1 decision) |
| U-3 | TTL plugin | 🔲 |
| U-4 | LRU plugin | 🔲 |

### Part 2: Transition (hivehook)

| Phase | Layer | Status |
|-------|-------|--------|
| 0 | Setup | 🔲 |
| 1 | Core | 🔲 |
| 2 | Storage Hooks | 🔲 |
| 3 | Integration | 🔲 |

---

## Commands

```bash
# hihook tests
cd hihook
dart test test/plugins/

# hivehook tests
cd hivehook2
dart test
```
