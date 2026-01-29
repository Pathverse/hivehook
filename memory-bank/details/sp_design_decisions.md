# Design Decisions (Resolved)

All design decisions have been resolved and implemented.

## Storage Architecture

| Decision | Choice |
|----------|--------|
| HiStore location | hihook `lib/interfaces/` |
| Metadata approach | Separate methods + HHive convenience |
| Event emission | HHive facade emits, HBoxStore is pure |
| Storage modes | JSON (default) + Native (TypeAdapter) |
| Global defaults | Adapters, encoder, decoder, hooks |

## Env Isolation (Jan 2026)

| Decision | Choice |
|----------|--------|
| Env uniqueness | Throw on duplicate registration |
| boxName | Separate from env, defaults to env |
| Key format | `{env}::{key}` in `{boxName}` box |
| API transparency | Users see plain keys |
| Scoped operations | clear/delete only affect own env |

## Plugin Strategy

| Decision | Choice |
|----------|--------|
| Plugin storage access | Via `ctx.data['meta']` |
| Missing meta behavior | Graceful no-op |
| Web debug | Keep in hivehook (not upstreamed) |
