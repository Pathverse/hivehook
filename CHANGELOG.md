# Changelog

## 1.0.0-alpha.1

- Rebuilt on HiHook framework for advanced hook composition
- Environment isolation with scoped key prefixing
- Lazy BoxCollection opening on first access
- Simplified configuration API
- 112 tests passing

## 0.2.0

- Consolidated metadata into single box with namespaced keys
- Web debug mode for DevTools inspection
- Revamped example app

## 0.1.7

- Bump hive_ce version

## 0.1.6

- Added `cacheOnNullValues` option to `ifNotCached` methods
- Added static `clearAll` method
- `usesMeta` now defaults to `true`

## 0.1.5

- Fixed payload env propagation

## 0.1.4

- TTL plugin accepts string and int keys

## 0.1.3

- Added iteration methods

## 0.1.2

- Added `ifNotCached` method

## 0.1.1

- Simplified metadata serialization

## 0.1.0

- Initial release
- Hook system for intercepting Hive operations
- Plugin architecture with TTL and LRU built-in
- Serialization hooks for encryption and compression
- Metadata support
- Multiple isolated environments
- Web platform support
