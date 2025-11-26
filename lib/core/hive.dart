import 'package:hivehook/core/config.dart';

class HHive {
  static final Map<String, HHive> _instances = {};

  // instance
  final HHImmutableConfig config;

  HHive._internal(this.config);

  factory HHive({HHImmutableConfig? config, String? env}) {
    if (config == null && env == null) {
      throw ArgumentError(
        'Either config or env must be provided to create HHive instance.',
      );
    }

    if (config != null && env != null) {
      if (config.env != env) {
        throw ArgumentError(
          'Provided config env (${config.env}) does not match provided env ($env).',
        );
      }
    }

    final targetEnv = config?.env ?? env!;

    // Check if HHive instance already exists for this env
    if (_instances.containsKey(targetEnv)) {
      return _instances[targetEnv]!;
    }

    // If only env is provided, get or create config
    final finalConfig = config ?? HHImmutableConfig.instances[targetEnv];

    if (finalConfig == null) {
      throw ArgumentError(
        'No config found for env "$targetEnv". Please create one first by providing a config.',
      );
    }

    // Create new HHive instance
    final instance = HHive._internal(finalConfig);
    _instances[targetEnv] = instance;
    return instance;
  }

  Future<dynamic> close() async {
    
  }
}
