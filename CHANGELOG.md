## 0.1.3
* added iter methods

## 0.1.2
* added `ifNotCached` method to `HHive`

## 0.1.1
* **Improved Metadata Handling**: Removed unnecessary metadata serialization hooks (metadata is always `Map<String, dynamic>`)
* **Bug Fixes**: Fixed metadata serialization to only use JSON encoding and terminal hooks

## 0.1.0
* Initial release of HiveHook
* Hook system for intercepting Hive operations (pre/post execution)
* Plugin architecture for composable, reusable middleware
* Action hooks for validation, logging, and custom logic
* Serialization hooks for data transformation (encryption, compression, JSON)
* Built-in TTL plugin for automatic data expiration
* Built-in LRU plugin for size-limited caching with automatic eviction
* Metadata support for storing additional context alongside values
* Control flow management (break, skip, delete operations)
* Type-safe API with comprehensive error handling
* Support for multiple isolated environments
* Web platform support via Hive CE
* Interactive web demo showcasing all features
* Complete test coverage
