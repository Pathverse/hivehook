import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/hooks/serialization_hook.dart';

class HHConfig {
  final String env;
  final List<HActionHook> actionHooks;
  final bool usesMeta;
  final List<SerializationHook> serializationHooks;
  final List<TerminalSerializationHook> terminalSerializationHooks;

  HHConfig({
    required this.env,
    this.actionHooks = const [],
    this.serializationHooks = const [],
    this.terminalSerializationHooks = const [],
    this.usesMeta = true,
  }) {
    // env cannot start with _
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

  final List<SerializationHook> metaSerializationHooks;
  final List<SerializationHook> storeSerializationHooks;
  final List<TerminalSerializationHook> metaTerminalSerializationHooks;
  final List<TerminalSerializationHook> storeTerminalSerializationHooks;

  HHImmutableConfig._internal(
    Map<String, List<HActionHook>> preHooks,
    Map<String, List<HActionHook>> postHooks,
    this.metaSerializationHooks,
    this.storeSerializationHooks,
    this.metaTerminalSerializationHooks,
    this.storeTerminalSerializationHooks, {
    required super.env,
    required this.usesMeta,
    super.actionHooks = const [],
    super.serializationHooks = const [],
    super.terminalSerializationHooks = const [],
  }) : preActionHooks = Map.unmodifiable(preHooks),
       postActionHooks = Map.unmodifiable(postHooks),
       super();

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
    final Map<String, List<HActionHook>> preHooks = {};
    final Map<String, List<HActionHook>> postHooks = {};

    for (var hook in actionHooks) {
      for (var latch in hook.latches) {
        final eventName = latch.customEvent ?? latch.triggerType.name;

        if (latch.isPost) {
          postHooks.putIfAbsent(eventName, () => []).add(hook);
        } else {
          preHooks.putIfAbsent(eventName, () => []).add(hook);
        }
      }
    }

    // Sort each event's hooks by priority (higher priority first)
    preHooks.forEach((event, hooks) {
      hooks.sort((a, b) {
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
    });

    postHooks.forEach((event, hooks) {
      hooks.sort((a, b) {
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
    });

    // Separate serialization hooks by meta and store
    final metaSerializationHooks = serializationHooksParam
        .where((hook) => hook.forMeta)
        .toList();
    final storeSerializationHooks = serializationHooksParam
        .where((hook) => hook.forStore)
        .toList();

    // Terminal serialization hooks - separate by context
    final metaTerminalSerializationHooks = <TerminalSerializationHook>[];
    final storeTerminalSerializationHooks = <TerminalSerializationHook>[];

    // For now, all terminal hooks go to store (can be enhanced later)
    storeTerminalSerializationHooks.addAll(terminalSerializationHooksParam);

    final newInstance = HHImmutableConfig._internal(
      preHooks,
      postHooks,
      metaSerializationHooks,
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
