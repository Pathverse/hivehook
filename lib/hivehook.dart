/// Hivehook - A minimal Hive storage adapter for hihook.
///
/// Hivehook provides a clean facade over Hive CE with integration to the
/// hihook engine for hook-based lifecycle management.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:hivehook/hivehook.dart';
/// import 'package:hihook/hihook.dart';
///
/// // 1. Register environment
/// HHiveCore.register(HiveConfig(
///   env: 'users',
///   withMeta: true,
///   hooks: [myLoggingHook, myTTLPlugin.hook],
/// ));
///
/// // 2. Initialize
/// await HHiveCore.initialize();
///
/// // 3. Create facade
/// final hive = await HHive.create('users');
///
/// // 4. CRUD operations (hooks are applied automatically)
/// await hive.put('user:1', {'name': 'Alice'}, meta: {'ttl': 3600});
/// final user = await hive.get<Map>('user:1');
/// await hive.delete('user:1');
/// ```
///
/// ## Architecture
///
/// ```
/// User Code → HHive (facade) → HiEngine (hooks) → HBoxStore (pure) → Hive
/// ```
///
/// - [HHive] - User-facing facade that emits events to hihook
/// - [HHiveCore] - Centralized Hive initialization & lifecycle
/// - [HBoxStore] - Pure HiStore implementation (no hook logic)
/// - [HiveConfig] - Configuration for environments
library hivehook;

// Re-export hihook essentials for convenience
export 'package:hihook/src/engine/engine.dart' show HiEngine;
export 'package:hihook/src/core/result.dart';
export 'package:hihook/src/core/payload.dart' show HiPayload;
export 'package:hihook/src/hook/hook.dart' show HiHook;
export 'package:hihook/interfaces/hi_store.dart';

// Hivehook core
export 'src/hhive.dart';
export 'src/core/hive_core.dart';
export 'src/core/hive_config.dart';
export 'src/store/hbox_store.dart';
