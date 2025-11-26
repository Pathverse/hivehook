# Project Brief: HiveHook

## Overview
HiveHook is a Dart package that extends Hive (a fast, NoSQL database) with a powerful hook system for intercepting and modifying database operations.

## Core Purpose
Provide a flexible, event-driven wrapper around Hive that allows developers to:
- Execute custom logic before/after database operations
- Transform data during serialization/deserialization
- Implement cross-cutting concerns (validation, logging, encryption, etc.)
- Control operation flow with structured exceptions

## Key Requirements

### Functional Requirements
1. **Hook System**: Support action hooks (pre/post operation) and serialization hooks (data transformation)
2. **Plugin System**: Group related hooks into plugins that can be installed/uninstalled as units
3. **Hook UIDs**: Every hook has a unique identifier for tracking and removal
4. **Context Management**: Provide rich context objects for hooks to access operation details
5. **Control Flow**: Enable hooks to modify execution flow (skip, break, continue, delete, pop, panic)
6. **Metadata Support**: Allow storing metadata alongside values
7. **Configuration**: Support multiple isolated environments with independent configurations
8. **Type Safety**: Maintain strong typing while providing flexibility

### Technical Requirements
1. **No Infinite Loops**: Hooks must be able to call HiveHook methods without causing recursion
2. **Clean Architecture**: Separate concerns between API layer, access layer, and serialization
3. **Performance**: Minimize overhead while maintaining functionality
4. **Testing**: Comprehensive test coverage for all features

## Architecture Principles

### Layer Separation
- **HHive (API Layer)**: Emits action events, manages user-facing API
- **HHCtxDirectAccess (Access Layer)**: Handles direct data access and serialization hooks
- **HHCtxControl (Control Layer)**: Manages hook execution and control flow

### Key Design Decision
Action events (valueRead, valueWrite, etc.) are emitted at the API layer (HHive), NOT in the direct access layer. This prevents infinite loops when hooks call HiveHook methods.

## Non-Goals
- Not a replacement for Hive, but an extension
- Not focused on performance optimization (Hive handles that)
- Not providing a query language (use Hive's native methods)

## Success Criteria
1. All tests pass without infinite loops
2. Hooks can safely call HiveHook methods
3. Clear separation of concerns between layers
4. Easy to use and understand API
