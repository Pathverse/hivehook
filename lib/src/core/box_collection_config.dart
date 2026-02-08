import 'package:hive_ce/hive.dart';

/// Configuration for a BoxCollection.
///
/// Allows per-collection settings for path, cipher, and meta handling.
/// Can be pre-registered or auto-created when HiveConfig references a collection.
///
/// Example:
/// ```dart
/// // Pre-configure collection
/// HHiveCore.registerCollection(BoxCollectionConfig(
///   name: 'myapp',
///   path: '/custom/path',
///   cipher: myCipher,
///   includeMeta: true,
/// ));
///
/// // Or let it auto-create with defaults
/// HHiveCore.register(HiveConfig(env: 'users', boxCollectionName: 'myapp'));
/// ```
class BoxCollectionConfig {
  /// Collection name (unique identifier).
  final String name;

  /// Storage path override for this collection.
  /// Falls back to global [HHiveCore.HIVE_INIT_PATH] if null.
  final String? path;

  /// Encryption cipher for this collection.
  /// Falls back to global [HHiveCore.HIVE_CIPHER] if null.
  final HiveCipher? cipher;

  /// Box names in this collection.
  ///
  /// Auto-populated from HiveConfig registrations.
  /// Can be pre-declared for external access or validation.
  final Set<String> boxNames;

  /// Whether to include `_meta` box in this collection.
  ///
  /// - `null` (default): Auto-detect from HiveConfig.withMeta
  /// - `true`: Always include `_meta`
  /// - `false`: Never include (errors if HiveConfig.withMeta conflicts)
  final bool? includeMeta;

  /// Whether this config was explicitly registered.
  ///
  /// Auto-created configs use global defaults; explicit ones use provided values.
  final bool isExplicit;

  const BoxCollectionConfig({
    required this.name,
    this.path,
    this.cipher,
    this.boxNames = const {},
    this.includeMeta,
    this.isExplicit = true,
  });

  /// Creates a default config for auto-creation.
  factory BoxCollectionConfig.defaults(String name) {
    return BoxCollectionConfig(
      name: name,
      boxNames: {},
      includeMeta: null,
      isExplicit: false,
    );
  }

  /// Creates a copy with updated values.
  BoxCollectionConfig copyWith({
    String? name,
    String? path,
    HiveCipher? cipher,
    Set<String>? boxNames,
    bool? includeMeta,
    bool? isExplicit,
  }) {
    return BoxCollectionConfig(
      name: name ?? this.name,
      path: path ?? this.path,
      cipher: cipher ?? this.cipher,
      boxNames: boxNames ?? this.boxNames,
      includeMeta: includeMeta ?? this.includeMeta,
      isExplicit: isExplicit ?? this.isExplicit,
    );
  }

  /// Validates the configuration.
  void validate() {
    if (name.isEmpty) {
      throw ArgumentError('BoxCollectionConfig.name cannot be empty');
    }
  }

  /// Whether `_meta` should be included based on current state.
  ///
  /// [hasMetaConfig] - true if any HiveConfig.withMeta == true references this collection.
  bool shouldIncludeMeta(bool hasMetaConfig) {
    if (includeMeta == true) return true;
    if (includeMeta == false) return false;
    return hasMetaConfig; // null = auto-detect
  }

  /// Validates meta inclusion against HiveConfig requirements.
  ///
  /// Throws if includeMeta == false but a HiveConfig requires meta.
  void validateMetaRequirement(bool requiresMeta) {
    if (includeMeta == false && requiresMeta) {
      throw StateError(
        'BoxCollectionConfig "$name" has includeMeta=false, '
        'but a HiveConfig with withMeta=true references this collection.',
      );
    }
  }

  @override
  String toString() =>
      'BoxCollectionConfig(name: $name, boxNames: $boxNames, includeMeta: $includeMeta)';
}
