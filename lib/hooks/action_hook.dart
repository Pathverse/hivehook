import 'package:hivehook/core/i_ctx.dart';
import 'package:hivehook/core/latch.dart';
import 'package:hivehook/hooks/base_hook.dart';

/// Hook that executes custom logic at specific points in the operation lifecycle.
/// Use [latches] to specify when this hook should execute.
class HActionHook extends BaseHook {
  final List<HHLatch> latches;
  final Future<dynamic> Function(HHCtxI ctx) action;

  HActionHook({required this.latches, required this.action});
}
