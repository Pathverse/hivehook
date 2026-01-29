# Tech Context

## Dependencies

```yaml
dependencies:
  hive_ce: ^2.19.1
  hihook:
    path: ../hihook
```

## Environment

- Dart SDK: ^3.9.0
- Platforms: All (web via IndexedDB, native via file)

## Key Technologies

| Tech | Purpose |
|------|---------|
| hive_ce | Persistence (BoxCollection) |
| hihook | Hook execution engine |

## Development

```bash
dart pub get
dart test          # 112 tests
dart analyze lib   # No issues
```

## File Structure

```
lib/
├── hivehook.dart       # Barrel export
└── src/
    ├── hhive.dart      # Facade
    ├── core/
    │   ├── hive_config.dart
    │   └── hive_core.dart
    └── store/
        └── hbox_store.dart
```
