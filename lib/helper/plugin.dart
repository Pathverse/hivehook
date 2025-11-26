import 'package:hivehook/hooks/action_hook.dart';
import 'package:hivehook/hooks/serialization_hook.dart';

int _uidCounter = 0;

class HHPlugin {
  final String uid = 'plugin_${_uidCounter++}';
  final List<HActionHook> actionHooks;
  final List<SerializationHook> serializationHooks;
  final List<TerminalSerializationHook> terminalSerializationHooks;

  HHPlugin({
    this.actionHooks = const [],
    this.serializationHooks = const [],
    this.terminalSerializationHooks = const [],
  }) {
    final len1 = actionHooks.length;
    final len2 = serializationHooks.length;
    final len3 = terminalSerializationHooks.length;

    if (len1 + len2 + len3 == 0) {
      throw ArgumentError(
        'A plugin must have at least one hook (action, serialization, or terminal serialization).',
      );
    }
  }
}
