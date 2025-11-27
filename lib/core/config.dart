import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/hooks/serialization_hook.dart';
import 'package:hivehook/helper/plugin.dart';

class HHConfig {
  final String env;
  final List<HActionHook> actionHooks;
  final bool usesMeta;
  final List<SerializationHook> serializationHooks;
  final List<TerminalSerializationHook> terminalSerializationHooks;
  final Map<String, HHPlugin> _installedPlugins = {};

  HHConfig({
    required this.env,
    List<HActionHook>? actionHooks,
    List<SerializationHook>? serializationHooks,
    List<TerminalSerializationHook>? terminalSerializationHooks,
    this.usesMeta = true,
  }) : actionHooks = actionHooks != null ? List.from(actionHooks) : [],
       serializationHooks = serializationHooks != null
           ? List.from(serializationHooks)
           : [],
       terminalSerializationHooks = terminalSerializationHooks != null
           ? List.from(terminalSerializationHooks)
           : [] {
    // env cannot start with _
    if (env.startsWith('_')) {
      throw ArgumentError(
        'Environment name cannot start with an underscore (_).',
      );
    }

    // If usesMeta is false, no action hooks are allowed
    if (!usesMeta && this.actionHooks.isNotEmpty) {
      throw ArgumentError(
        'Action hooks are not allowed when usesMeta is false.',
      );
    }
  }

  /// Get all installed plugins
  Map<String, HHPlugin> get installedPlugins =>
      Map.unmodifiable(_installedPlugins);

  /// Install a plugin by adding all its hooks to the configuration
  void installPlugin(HHPlugin plugin) {
    if (_installedPlugins.containsKey(plugin.uid)) {
      throw ArgumentError('Plugin "${plugin.uid}" is already installed.');
    }

    // Add all plugin hooks to the respective lists
    actionHooks.addAll(plugin.actionHooks);
    serializationHooks.addAll(plugin.serializationHooks);
    terminalSerializationHooks.addAll(plugin.terminalSerializationHooks);

    _installedPlugins[plugin.uid] = plugin;
  }

  /// Uninstall a plugin by removing all its hooks from the configuration
  void uninstallPlugin(String pluginUid) {
    if (!_installedPlugins.containsKey(pluginUid)) {
      throw ArgumentError('Plugin "$pluginUid" is not installed.');
    }

    final plugin = _installedPlugins[pluginUid]!;

    // Remove plugin hooks by UID
    final actionHookUids = plugin.actionHooks.map((h) => h.uid).toSet();
    actionHooks.removeWhere((hook) => actionHookUids.contains(hook.uid));

    final serializationHookUids = plugin.serializationHooks
        .map((h) => h.uid)
        .toSet();
    serializationHooks.removeWhere(
      (hook) => serializationHookUids.contains(hook.uid),
    );

    final terminalSerializationHookUids = plugin.terminalSerializationHooks
        .map((h) => h.uid)
        .toSet();
    terminalSerializationHooks.removeWhere(
      (hook) => terminalSerializationHookUids.contains(hook.uid),
    );

    _installedPlugins.remove(pluginUid);
  }

  HHImmutableConfig finalize() {
    return HHImmutableConfig(
      env: env,
      actionHooks: actionHooks,
      usesMeta: usesMeta,
      serializationHooksParam: serializationHooks,
      terminalSerializationHooksParam: terminalSerializationHooks,
    );
  }
}

class HHImmutableConfig extends HHConfig {
  static final Map<String, HHImmutableConfig> _instances = {};

  static Map<String, HHImmutableConfig> get instances =>
      Map.unmodifiable(_instances);

  static HHImmutableConfig? getInstance(String env) => _instances[env];

  late final Map<String, List<HActionHook>> preActionHooks;
  late final Map<String, List<HActionHook>> postActionHooks;
  final bool usesMeta;

  final List<SerializationHook> storeSerializationHooks;
  final List<TerminalSerializationHook> metaTerminalSerializationHooks;
  final List<TerminalSerializationHook> storeTerminalSerializationHooks;

  HHImmutableConfig._internal(
    Map<String, List<HActionHook>> preHooks,
    Map<String, List<HActionHook>> postHooks,
    this.storeSerializationHooks,
    this.metaTerminalSerializationHooks,
    this.storeTerminalSerializationHooks, {
    required super.env,
    required this.usesMeta,
    List<HActionHook>? actionHooks,
    List<SerializationHook>? serializationHooks,
    List<TerminalSerializationHook>? terminalSerializationHooks,
  }) : preActionHooks = Map.unmodifiable(preHooks),
       postActionHooks = Map.unmodifiable(postHooks),
       super(
         actionHooks: actionHooks,
         serializationHooks: serializationHooks,
         terminalSerializationHooks: terminalSerializationHooks,
       );

  /// Throws error - immutable config cannot install plugins
  @override
  void installPlugin(HHPlugin plugin) {
    throw UnsupportedError(
      'Cannot install plugin on HHImmutableConfig. '
      'Plugins can only be installed on mutable HHConfig before finalization.',
    );
  }

  /// Throws error - immutable config cannot uninstall plugins
  @override
  void uninstallPlugin(String pluginName) {
    throw UnsupportedError(
      'Cannot uninstall plugin from HHImmutableConfig. '
      'Plugins can only be uninstalled from mutable HHConfig before finalization.',
    );
  }

  factory HHImmutableConfig({
    required String env,
    List<HActionHook> actionHooks = const [],
    bool usesMeta = true,
    List<SerializationHook> serializationHooksParam = const [],
    List<TerminalSerializationHook> terminalSerializationHooksParam = const [],
  }) {
    // env validation
    if (env.startsWith('_')) {
      throw ArgumentError(
        'Environment name cannot start with an underscore (_).',
      );
    }

    // If usesMeta is false, no action hooks are allowed
    if (!usesMeta && actionHooks.isNotEmpty) {
      throw ArgumentError(
        'Action hooks are not allowed when usesMeta is false.',
      );
    }

    if (_instances.containsKey(env)) {
      final existingInstance = _instances[env]!;

      // Check if settings are identical
      final isIdentical =
          existingInstance.actionHooks.length == actionHooks.length;

      if (!isIdentical) {
        throw ArgumentError(
          'Config with env "$env" already exists with different settings.',
        );
      }

      return existingInstance;
    }

    // Group hooks by event name and pre/post status
    final Map<String, Set<HActionHook>> preHooks = {};
    final Map<String, Set<HActionHook>> postHooks = {};

    for (var hook in actionHooks) {
      for (var latch in hook.latches) {
        final eventName = latch.customEvent ?? latch.triggerType.name;

        if (latch.isPost) {
          postHooks.putIfAbsent(eventName, () => {}).add(hook);
        } else {
          preHooks.putIfAbsent(eventName, () => {}).add(hook);
        }
      }
    }

    // Sort each event's hooks by priority (higher priority first) and convert to lists
    final Map<String, List<HActionHook>> sortedPreHooks = {};
    preHooks.forEach((event, hooksSet) {
      final hooksList = hooksSet.toList();
      hooksList.sort((a, b) {
        final aPriority = a.latches
            .where(
              (l) =>
                  (l.customEvent ?? l.triggerType.name) == event && !l.isPost,
            )
            .map((l) => l.priority)
            .fold(0, (max, p) => p > max ? p : max);
        final bPriority = b.latches
            .where(
              (l) =>
                  (l.customEvent ?? l.triggerType.name) == event && !l.isPost,
            )
            .map((l) => l.priority)
            .fold(0, (max, p) => p > max ? p : max);
        return bPriority.compareTo(aPriority);
      });
      sortedPreHooks[event] = hooksList;
    });

    final Map<String, List<HActionHook>> sortedPostHooks = {};
    postHooks.forEach((event, hooksSet) {
      final hooksList = hooksSet.toList();
      hooksList.sort((a, b) {
        final aPriority = a.latches
            .where(
              (l) => (l.customEvent ?? l.triggerType.name) == event && l.isPost,
            )
            .map((l) => l.priority)
            .fold(0, (max, p) => p > max ? p : max);
        final bPriority = b.latches
            .where(
              (l) => (l.customEvent ?? l.triggerType.name) == event && l.isPost,
            )
            .map((l) => l.priority)
            .fold(0, (max, p) => p > max ? p : max);
        return bPriority.compareTo(aPriority);
      });
      sortedPostHooks[event] = hooksList;
    });

    // Only store serialization hooks are used (metadata is always Map<String, dynamic>)
    final storeSerializationHooks = serializationHooksParam
        .where((hook) => hook.forStore)
        .toList();

    // Terminal serialization hooks - separate by context
    final metaTerminalSerializationHooks = <TerminalSerializationHook>[];
    final storeTerminalSerializationHooks = <TerminalSerializationHook>[];

    // For now, all terminal hooks go to store (can be enhanced later)
    storeTerminalSerializationHooks.addAll(terminalSerializationHooksParam);

    final newInstance = HHImmutableConfig._internal(
      sortedPreHooks,
      sortedPostHooks,
      storeSerializationHooks,
      metaTerminalSerializationHooks,
      storeTerminalSerializationHooks,
      env: env,
      usesMeta: usesMeta,
      actionHooks: actionHooks,
      serializationHooks: serializationHooksParam,
      terminalSerializationHooks: terminalSerializationHooksParam,
    );

    _instances[env] = newInstance;
    return newInstance;
  }

  // ==
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HHConfig && runtimeType == other.runtimeType && env == other.env;

  @override
  int get hashCode => env.hashCode;
}

void dangerousReplaceConfig(dynamic config) {
  if (config is! HHConfig) {
    throw ArgumentError('Provided config is not of type HHConfig.');
  }
  if (config is HHImmutableConfig) {
    // print(
    //   'DEBUG dangerousReplaceConfig: Replacing HHImmutableConfig for env=${config.env}',
    // );
    HHImmutableConfig._instances[config.env] = config;
  } else {
    // print(
    //   'DEBUG dangerousReplaceConfig: Replacing HHConfig for env=${config.env}, actionHooks count=${config.actionHooks.length}',
    // );
    // Remove existing instance first to avoid validation error
    HHImmutableConfig._instances.remove(config.env);
    final finalizedConfig = config.finalize();
    // print(
    //   'DEBUG dangerousReplaceConfig: Finalized config has ${finalizedConfig.actionHooks.length} actionHooks',
    // );
    // print(
    //   'DEBUG dangerousReplaceConfig: preActionHooks[valueWrite] count=${finalizedConfig.preActionHooks["valueWrite"]?.length ?? 0}',
    // );
    HHImmutableConfig._instances[finalizedConfig.env] = finalizedConfig;
  }
}

void dangerousClearAllConfigs() {
  HHImmutableConfig._instances.clear();
}

void dangerousRemoveConfig(HHImmutableConfig config) {
  HHImmutableConfig._instances.remove(config.env);
}
