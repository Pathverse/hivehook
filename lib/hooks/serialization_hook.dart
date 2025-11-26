import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/hooks/base_hook.dart';

abstract class TerminalSerializationHook extends BaseHook {
  Future<String> serialize(String value, HHCtxI ctx);
  Future<String> deserialize(String value, HHCtxI ctx);
}

class SerializationHook extends BaseHook {
  final Future<String> Function(HHCtxI ctx) serialize;
  final Future<String> Function(HHCtxI ctx) deserialize;
  final Future<bool> Function(HHCtxI ctx)? canHandle;
  final bool silentOnError;
  final Future<void> Function(HHCtxI ctx)? onError;
  final bool forMeta;
  final bool forStore;

  SerializationHook({
    required this.serialize,
    required this.deserialize,
    this.canHandle,
    this.onError,
    this.silentOnError = false,
    this.forMeta = false,
    this.forStore = true,
  });
}
