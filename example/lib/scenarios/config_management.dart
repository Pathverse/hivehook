import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

class ConfigManagementScenario extends Scenario {
  @override
  String get name => 'Config Management';

  @override
  String get description =>
      'Multi-environment configuration with feature flags and overrides';

  @override
  IconData get icon => Icons.settings;

  @override
  List<String> get tags => ['multi-env', 'config', 'feature-flags'];

  @override
  Future<void> run(LogCallback log) async {
    final environments = ['development', 'staging', 'production'];

    final baseConfig = <String, dynamic>{
      'app': {'name': 'MyAwesomeApp', 'version': '2.5.0', 'build': 2050},
      'api': {
        'timeout': 30000,
        'retries': 3,
        'endpoints': {
          'auth': '/api/v2/auth',
          'users': '/api/v2/users',
          'products': '/api/v2/products',
        },
      },
      'features': {
        'darkMode': {'enabled': true, 'default': false},
        'biometricAuth': {'enabled': true, 'default': true},
        'offlineMode': {'enabled': true, 'default': false},
        'newCheckoutFlow': {'enabled': false, 'default': false},
        'aiAssistant': {'enabled': false, 'default': false},
      },
      'ui': {
        'theme': {
          'primaryColor': '#6200EE',
          'secondaryColor': '#03DAC6',
        },
        'animation': {'enabled': true, 'durationMs': 300},
      },
      'logging': {'level': 'debug', 'console': true, 'remote': false},
      'security': {
        'ssl': {'enabled': true, 'pinning': false, 'allowSelfSigned': true},
        'encryption': {'enabled': false, 'algorithm': 'AES-256-GCM'},
      },
    };

    final envOverrides = <String, Map<String, dynamic>>{
      'development': {
        'api': {'baseUrl': 'http://localhost:3000'},
        'logging': {'level': 'debug', 'console': true},
        'security': {
          'ssl': {'enabled': false, 'allowSelfSigned': true}
        },
        'features': {
          'newCheckoutFlow': {'enabled': true},
          'aiAssistant': {'enabled': true},
        },
      },
      'staging': {
        'api': {'baseUrl': 'https://staging-api.example.com'},
        'logging': {'level': 'info', 'remote': true},
        'security': {
          'ssl': {'pinning': true, 'allowSelfSigned': false}
        },
        'features': {'newCheckoutFlow': {'enabled': true}},
      },
      'production': {
        'api': {'baseUrl': 'https://api.example.com'},
        'logging': {'level': 'warn', 'console': false, 'remote': true},
        'security': {
          'ssl': {'pinning': true, 'allowSelfSigned': false},
          'encryption': {'enabled': true},
        },
      },
    };

    log('Setting up multi-environment configuration system...');
    log('Environments: ${environments.join(', ')}', level: LogLevel.data);

    // Store base config
    final baseHive = await HHive.create('demo');
    await baseHive.put('config/base', baseConfig);
    log('\n✓ Base config stored', level: LogLevel.success);

    // Store environment-specific configs
    for (final env in environments) {
      final merged = _deepMerge(
        Map<String, dynamic>.from(baseConfig),
        Map<String, dynamic>.from(envOverrides[env]!),
      );
      await baseHive.put('config/$env', merged);
      log('✓ $env config stored', level: LogLevel.success);
    }

    // Compare environments
    log('\n━━━ Environment Comparison ━━━', level: LogLevel.info);

    for (final env in environments) {
      final config =
          await baseHive.get('config/$env') as Map<String, dynamic>;

      log('\n[$env]', level: LogLevel.info);

      final api = config['api'] as Map<String, dynamic>;
      log('  API: ${api['baseUrl'] ?? 'inherited'}', level: LogLevel.data);

      final security = config['security'] as Map<String, dynamic>;
      final ssl = security['ssl'] as Map<String, dynamic>;
      log('  SSL Pinning: ${ssl['pinning']}', level: LogLevel.data);

      final logging = config['logging'] as Map<String, dynamic>;
      log('  Log Level: ${logging['level']}', level: LogLevel.data);
      log('  Remote Logging: ${logging['remote']}', level: LogLevel.data);

      // Feature flags
      final features = config['features'] as Map<String, dynamic>;
      final enabledFeatures = <String>[];
      for (final entry in features.entries) {
        final feat = entry.value as Map<String, dynamic>;
        if (feat['enabled'] == true) {
          enabledFeatures.add(entry.key);
        }
      }
      log('  Features (${enabledFeatures.length}): ${enabledFeatures.take(3).join(', ')}${enabledFeatures.length > 3 ? '...' : ''}',
          level: LogLevel.data);
    }

    // Feature flag check
    log('\n━━━ Feature Flag Check (staging) ━━━', level: LogLevel.info);
    final stagingConfig =
        await baseHive.get('config/staging') as Map<String, dynamic>;
    final featuresToCheck = [
      'darkMode',
      'newCheckoutFlow',
      'aiAssistant',
      'biometricAuth'
    ];

    final stagingFeatures = stagingConfig['features'] as Map<String, dynamic>;
    for (final feature in featuresToCheck) {
      final featureConfig = stagingFeatures[feature] as Map<String, dynamic>;
      final enabled = featureConfig['enabled'] as bool;
      final icon = enabled ? '✓' : '✗';
      final level = enabled ? LogLevel.success : LogLevel.warning;
      log('  $icon $feature: ${enabled ? 'enabled' : 'disabled'}', level: level);
    }

    log('\n✓ Configuration management demo complete', level: LogLevel.success);
  }

  Map<String, dynamic> _deepMerge(
      Map<String, dynamic> base, Map<String, dynamic> override) {
    final result = Map<String, dynamic>.from(base);

    for (final entry in override.entries) {
      if (entry.value is Map && result[entry.key] is Map) {
        result[entry.key] = _deepMerge(
          Map<String, dynamic>.from(result[entry.key] as Map),
          Map<String, dynamic>.from(entry.value as Map),
        );
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }
}
