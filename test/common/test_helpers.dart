import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:hihook/src/context/context.dart';
import 'package:hihook/src/core/types.dart';
import 'package:hivehook/hivehook.dart';

/// Random number generator for unique names.
final _random = Random.secure();

/// Base temp path for test files.
String get tempPath =>
    path.join(Directory.current.path, '.dart_tool', 'test', 'tmp');

/// Creates a unique temp directory for test isolation.
Future<Directory> getTempDir() async {
  final name = _random.nextInt(1 << 30);
  final dir = Directory(path.join(tempPath, '${name}_tmp'));
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  await dir.create(recursive: true);
  return dir;
}

/// Generates a unique environment name.
String generateEnvName() {
  final id = _random.nextInt(99999999);
  return 'env$id';
}

/// Generates a unique box collection name.
String generateCollectionName() {
  final id = _random.nextInt(99999999);
  return 'collection$id';
}

/// Cleans up all Hive test artifacts from the workspace root.
/// 
/// Deletes:
/// - All collection* folders
/// - All *.hive and *.lock files in workspace root
/// - The .dart_tool/test/tmp folder
Future<void> cleanupHiveFiles() async {
  final workspaceDir = Directory.current;
  
  // Clean collection* folders in workspace root
  await for (final entity in workspaceDir.list()) {
    if (entity is Directory) {
      final name = path.basename(entity.path);
      if (name.startsWith('collection')) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // Ignore errors (file in use, etc.)
        }
      }
    }
  }
  
  // Clean .hive and .lock files in workspace root
  await for (final entity in workspaceDir.list()) {
    if (entity is File) {
      final name = path.basename(entity.path);
      if (name.endsWith('.hive') || name.endsWith('.lock')) {
        try {
          await entity.delete();
        } catch (_) {
          // Ignore errors
        }
      }
    }
  }
  
  // Clean temp test folder
  final tempDir = Directory(tempPath);
  if (await tempDir.exists()) {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Ignore errors
    }
  }
}

/// Resets all HHiveCore state and HHive instances.
///
/// Call in setUp/tearDown for test isolation.
/// Also cleans up Hive file artifacts.
Future<void> resetHiveState() async {
  await HHiveCore.resetAll();
  HHive.disposeAll();
  await cleanupHiveFiles();
}

/// Creates and initializes HHiveCore with a temp directory.
///
/// Returns the temp directory path for cleanup.
Future<String> initHiveCore({
  List<HiveConfig>? configs,
}) async {
  final dir = await getTempDir();
  HHiveCore.HIVE_INIT_PATH = dir.path;
  
  if (configs != null) {
    for (final config in configs) {
      HHiveCore.register(config);
    }
  }
  
  await HHiveCore.initialize();
  return dir.path;
}

/// Creates HHive with a simple config for testing.
Future<HHive> createTestHive({
  String? env,
  bool withMeta = true,
  List<HiHook>? hooks,
  HiveStorageMode storageMode = HiveStorageMode.json,
  HiveJsonEncoder? jsonEncoder,
  HiveJsonDecoder? jsonDecoder,
}) async {
  env ??= generateEnvName();
  
  HHiveCore.register(HiveConfig(
    env: env,
    boxCollectionName: generateCollectionName(),
    withMeta: withMeta,
    hooks: hooks ?? [],
    storageMode: storageMode,
    jsonEncoder: jsonEncoder,
    jsonDecoder: jsonDecoder,
  ));
  
  await HHiveCore.initialize();
  return HHive.create(env);
}

/// Mock time provider for TTL/LRU testing.
class MockTimeProvider {
  int _now;
  
  MockTimeProvider([int? startTime]) 
    : _now = startTime ?? DateTime.now().millisecondsSinceEpoch;
  
  int call() => _now;
  
  void advance(Duration duration) {
    _now += duration.inMilliseconds;
  }
  
  void set(int timestamp) {
    _now = timestamp;
  }
}

// --- Test Helper Hooks ---

/// Hook that injects metadata into context before other hooks run.
HiHook<dynamic, dynamic> injectMetaHook(Map<String, dynamic> meta) {
  return HiHook<dynamic, dynamic>(
    uid: 'test:inject-meta',
    events: ['read', 'write', 'delete', 'clear'],
    phase: HiPhase.pre,
    priority: 1000, // Run first
    handler: (payload, ctx) {
      final context = ctx as HiContext;
      context.dataTracked['meta'] = meta;
      return const HiContinue();
    },
  );
}

/// Hook that captures the final state after all hooks run.
HiHook<dynamic, dynamic> captureStateHook({
  List<String> events = const ['read', 'write'],
  required void Function(dynamic value, Map<String, dynamic>? meta) onCapture,
}) {
  return HiHook<dynamic, dynamic>(
    uid: 'test:capture-state',
    events: events,
    phase: HiPhase.post,
    priority: -1000, // Run last
    handler: (payload, ctx) {
      final context = ctx as HiContext;
      onCapture(
        payload.value,
        context.dataTracked['meta'] as Map<String, dynamic>?,
      );
      return const HiContinue();
    },
  );
}

/// Hook that tracks which events were emitted.
class EventTracker {
  final List<String> events = [];
  final List<String> keys = [];
  final List<dynamic> values = [];
  
  HiHook<dynamic, dynamic> get hook => HiHook<dynamic, dynamic>(
    uid: 'test:event-tracker',
    events: ['read', 'write', 'delete', 'clear'],
    phase: HiPhase.pre,
    priority: 999,
    handler: (payload, ctx) {
      final context = ctx as HiContext;
      events.add(context.event);
      keys.add(payload.key ?? '');
      values.add(payload.value);
      return const HiContinue();
    },
  );
  
  void clear() {
    events.clear();
    keys.clear();
    values.clear();
  }
}

/// Hook that blocks execution by returning HiBreak.
HiHook<T, T> blockingHook<T>({
  List<String> events = const ['read'],
  T? returnValue,
}) {
  return HiHook<T, T>(
    uid: 'test:blocking',
    events: events,
    handler: (payload, ctx) {
      return HiBreak(returnValue: returnValue);
    },
  );
}

/// Hook that deletes by returning HiDelete.
HiHook<dynamic, dynamic> deletingHook({
  List<String> events = const ['read'],
}) {
  return HiHook<dynamic, dynamic>(
    uid: 'test:deleting',
    events: events,
    handler: (payload, ctx) {
      return const HiDelete();
    },
  );
}

/// Hook that modifies the payload value.
HiHook<T, T> transformValueHook<T>({
  List<String> events = const ['write'],
  required T Function(T value) transform,
}) {
  return HiHook<T, T>(
    uid: 'test:transform',
    events: events,
    handler: (payload, ctx) {
      return HiContinue(
        payload: payload.copyWith(value: transform(payload.value)),
      );
    },
  );
}
