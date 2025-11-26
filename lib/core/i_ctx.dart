import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/payload.dart';

class HHCtrlException implements Exception {
  final NextPhase nextPhase;
  final dynamic returnValue;
  final Map<String, dynamic> runtimeMeta;
  HHCtrlException({
    this.nextPhase = NextPhase.f_break,
    this.returnValue,
    required Map<String, dynamic> runtimeMeta,
  }) : runtimeMeta = Map.unmodifiable(runtimeMeta);
}

class HHRuntimeException implements Exception {
  final String message;
  HHRuntimeException(this.message);
}

class HHCtxData {
  // ignore: unused_field
  final HHCtxI _ctx;
  HHCtxData(this._ctx);

  final Map<String, dynamic> runtimeData = {};
}

abstract class HHCtxControlI {
  final HHCtxI _ctx;
  HHCtxControlI(this._ctx);

  HHCtxI get ctx => _ctx;

  final List<String> _stage = [];

  void pushStage(String stageName) {
    _stage.add(stageName);
  }

  void popStage() {
    if (_stage.isNotEmpty) {
      _stage.removeLast();
    }
  }

  void pushSubStage(String subStageName) {
    if (_stage.isNotEmpty) {
      final lastStage = _stage.removeLast();
      _stage.add('$lastStage.$subStageName');
    } else {
      _stage.add(subStageName);
    }
  }

  void popSubStage() {
    if (_stage.isNotEmpty) {
      final lastStage = _stage.removeLast();
      final parts = lastStage.split('.');
      if (parts.length > 1) {
        parts.removeLast();
        _stage.add(parts.join('.'));
      }
    }
  }

  String? get currentStage => _stage.isNotEmpty ? _stage.last : null;

  Future<dynamic> emit(
    String eventName, {
    Future<dynamic> Function(HHCtxI ctx)? action,
    bool handleCtrlException = false,
  });
}

abstract class HHCtxDirectAccessI {
  final HHCtxI _ctx;
  HHCtxDirectAccessI(this._ctx);

  HHCtxI get ctx => _ctx;

  Future<dynamic> storeGet(String key);
  Future<void> storePut(String key, dynamic value);
  Future<void> storeDelete(String key);
  Future<dynamic> storePop(String key);
  Future<void> storeClear();
  Future<Map<String, dynamic>?> metaGet(String key);
  Future<void> metaPut(String key, Map<String, dynamic> value);
  Future<void> metaDelete(String key);
  Future<Map<String, dynamic>?> metaPop(String key);
  Future<void> metaClear();
}

abstract class HHCtxI {
  late final HHCtxControlI control;
  late final HHCtxData data;
  late final HHCtxDirectAccessI access;
  final HHImmutablePayload initialPayload;
  HHPayload payload;

  String get env;
  dynamic get config;

  HHCtxI(HHPayload? initialPayload)
    : initialPayload = HHImmutablePayload(
        key: initialPayload?.key,
        value: initialPayload?.value,
        metadata: initialPayload?.metadata ?? {},
      ),
      payload = HHPayload(
        key: initialPayload?.key,
        value: initialPayload?.value,
        metadata: initialPayload?.metadata ?? {},
      );
}
