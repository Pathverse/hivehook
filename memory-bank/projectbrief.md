# Project Brief

## Overview

**hivehook** is a Hive CE storage adapter for hihook (hook engine).

## Architecture

```
hihook   = Hook Engine + Plugins (TTL, LRU, Base64)
hivehook = HBoxStore implements HiStore (storage + facade)
```

## Components

| Component | Role |
|-----------|------|
| `HiStore` | Abstract storage interface (hihook) |
| `HBoxStore` | Hive implementation with env isolation |
| `HHiveCore` | Static manager, box lifecycle |
| `HHive` | User-facing facade |

## Key Features

- **Env isolation**: Keys stored as `{env}::{key}`
- **boxName sharing**: Multiple envs can share one box
- **Storage modes**: JSON (default) or Native (TypeAdapter)
- **Global defaults**: Hooks, adapters, encoders
