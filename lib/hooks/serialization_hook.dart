import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/hooks/base_hook.dart';

/// Terminal hook for infrastructure-level transformations (encryption, compression).
/// Always processes strings, applied after regular serialization hooks.
abstract class TerminalSerializationHook extends BaseHook {
  Future<String> serialize(String value, HHCtxI ctx);
  Future<String> deserialize(String value, HHCtxI ctx);
}

// type of both map or list
typedef SerializationValue = dynamic;

/// Hook for transforming data during serialization/deserialization.
/// Each hook has a unique [id] and is registered globally.
class SerializationHook extends BaseHook {
  static final Map<String, SerializationHook> _registeredHooks = {};

  final String id;
  final Future<SerializationValue> Function(HHCtxI ctx) serialize;
  final Future<dynamic> Function(HHCtxI ctx) deserialize;
  final Future<bool> Function(HHCtxI ctx)? canHandle;
  final bool silentOnError;
  final Future<void> Function(HHCtxI ctx)? onError;
  final bool forStore;

  SerializationHook({
    required this.id,
    required this.serialize,
    required this.deserialize,
    this.canHandle,
    this.onError,
    this.silentOnError = false,
    this.forStore = true,
  }) {
    if (_registeredHooks.containsKey(id)) {
      throw ArgumentError(
        'A SerializationHook with id "$id" is already registered.',
      );
    }

    _registeredHooks[id] = this;
  }

  /// Get a registered hook by ID
  static SerializationHook? getHook(String id) => _registeredHooks[id];
}
