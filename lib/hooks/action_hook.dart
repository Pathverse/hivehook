import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/core/latch.dart';

class HActionHook {
  final List<HHLatch> latches;
  final Future<dynamic> Function(HHCtxI ctx) action;

  HActionHook({
    required this.latches,
    required this.action,
  });
}
