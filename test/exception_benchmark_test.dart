import 'package:hivehook/core/enums.dart';
import 'package:hivehook/core/i_ctx.dart';
import 'package:test/test.dart';

void main() {
  group('Exception Overhead Benchmark', () {
    test('single throw/catch overhead', () {
      const iterations = 100000;

      // Warm up
      for (var i = 0; i < 1000; i++) {
        _singleThrowCatch();
        _returnResult();
      }

      // Test with exceptions
      final sw1 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _singleThrowCatch();
      }
      sw1.stop();

      // Test without exceptions
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _returnResult();
      }
      sw2.stop();

      final exceptionTime = sw1.elapsedMicroseconds;
      final resultTime = sw2.elapsedMicroseconds;
      final overhead = exceptionTime - resultTime;
      final perCall = overhead / iterations;

      print('\n=== Single Throw/Catch ===');
      print('With exceptions: ${exceptionTime}μs (${exceptionTime / 1000}ms)');
      print('Without exceptions: ${resultTime}μs (${resultTime / 1000}ms)');
      print('Total overhead: ${overhead}μs (${overhead / 1000}ms)');
      print('Per-call overhead: ${perCall.toStringAsFixed(3)}μs');

      expect(
        perCall,
        lessThan(100),
        reason: 'Exception overhead should be < 100μs per call',
      );
    });

    test('nested throw/catch (3 levels)', () {
      const iterations = 50000;

      // Warm up
      for (var i = 0; i < 1000; i++) {
        _nestedThrowCatch();
        _nestedReturn();
      }

      // Test with exceptions
      final sw1 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _nestedThrowCatch();
      }
      sw1.stop();

      // Test without exceptions
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _nestedReturn();
      }
      sw2.stop();

      final exceptionTime = sw1.elapsedMicroseconds;
      final resultTime = sw2.elapsedMicroseconds;
      final overhead = exceptionTime - resultTime;
      final perCall = overhead / iterations;

      print('\n=== Nested Throw/Catch (3 levels) ===');
      print('With exceptions: ${exceptionTime}μs (${exceptionTime / 1000}ms)');
      print('Without exceptions: ${resultTime}μs (${resultTime / 1000}ms)');
      print('Total overhead: ${overhead}μs (${overhead / 1000}ms)');
      print('Per-call overhead: ${perCall.toStringAsFixed(3)}μs');

      expect(
        perCall,
        lessThan(100),
        reason: 'Nested exception overhead should be < 100μs per call',
      );
    });

    test('hook chain simulation (5 hooks, 20% control flow)', () {
      const iterations = 10000;

      // Warm up
      for (var i = 0; i < 100; i++) {
        _simulateHookChainException(5, 0.2);
        _simulateHookChainResult(5, 0.2);
      }

      // Test with exceptions
      final sw1 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _simulateHookChainException(5, 0.2);
      }
      sw1.stop();

      // Test without exceptions
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _simulateHookChainResult(5, 0.2);
      }
      sw2.stop();

      final exceptionTime = sw1.elapsedMicroseconds;
      final resultTime = sw2.elapsedMicroseconds;
      final overhead = exceptionTime - resultTime;
      final perCall = overhead / iterations;

      print('\n=== Hook Chain Simulation (5 hooks, 20% control flow) ===');
      print('With exceptions: ${exceptionTime}μs (${exceptionTime / 1000}ms)');
      print('Without exceptions: ${resultTime}μs (${resultTime / 1000}ms)');
      print('Total overhead: ${overhead}μs (${overhead / 1000}ms)');
      print('Per-call overhead: ${perCall.toStringAsFixed(3)}μs');

      expect(
        perCall,
        lessThan(200),
        reason: 'Hook chain overhead should be < 200μs per call',
      );
    });

    test('worst case: every hook throws (100% control flow)', () {
      const iterations = 10000;

      // Warm up
      for (var i = 0; i < 100; i++) {
        _simulateHookChainException(5, 1.0);
        _simulateHookChainResult(5, 1.0);
      }

      // Test with exceptions
      final sw1 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _simulateHookChainException(5, 1.0);
      }
      sw1.stop();

      // Test without exceptions
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _simulateHookChainResult(5, 1.0);
      }
      sw2.stop();

      final exceptionTime = sw1.elapsedMicroseconds;
      final resultTime = sw2.elapsedMicroseconds;
      final overhead = exceptionTime - resultTime;
      final perCall = overhead / iterations;

      print('\n=== Worst Case: Every Hook Controls Flow (100%) ===');
      print('With exceptions: ${exceptionTime}μs (${exceptionTime / 1000}ms)');
      print('Without exceptions: ${resultTime}μs (${resultTime / 1000}ms)');
      print('Total overhead: ${overhead}μs (${overhead / 1000}ms)');
      print('Per-call overhead: ${perCall.toStringAsFixed(3)}μs');
    });

    test('different exception types overhead', () {
      const iterations = 50000;

      // Test different NextPhase values
      final phases = [
        NextPhase.f_break,
        NextPhase.f_skip,
        NextPhase.f_continue,
        NextPhase.f_delete,
        NextPhase.f_pop,
        NextPhase.f_panic,
      ];

      print('\n=== Exception Type Comparison ===');

      for (final phase in phases) {
        // Warm up
        for (var i = 0; i < 100; i++) {
          _throwSpecificException(phase);
        }

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          _throwSpecificException(phase);
        }
        sw.stop();

        final perCall = sw.elapsedMicroseconds / iterations;
        print(
          '${phase.toString().padRight(20)}: ${perCall.toStringAsFixed(3)}μs per call',
        );
      }
    });

    test('with metadata vs without metadata', () {
      const iterations = 50000;

      // Warm up
      for (var i = 0; i < 100; i++) {
        _throwWithMetadata();
        _throwWithoutMetadata();
      }

      // With metadata
      final sw1 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _throwWithMetadata();
      }
      sw1.stop();

      // Without metadata
      final sw2 = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        _throwWithoutMetadata();
      }
      sw2.stop();

      final withMeta = sw1.elapsedMicroseconds / iterations;
      final withoutMeta = sw2.elapsedMicroseconds / iterations;

      print('\n=== Metadata Overhead ===');
      print('With metadata: ${withMeta.toStringAsFixed(3)}μs per call');
      print('Without metadata: ${withoutMeta.toStringAsFixed(3)}μs per call');
      print(
        'Metadata overhead: ${(withMeta - withoutMeta).toStringAsFixed(3)}μs per call',
      );
    });
  });
}

// === Single throw/catch ===

dynamic _singleThrowCatch() {
  try {
    throw HHCtrlException(nextPhase: NextPhase.f_break, returnValue: 'test');
  } on HHCtrlException catch (e) {
    return e.returnValue;
  }
}

dynamic _returnResult() {
  return _ControlResult(
    isControl: true,
    value: 'test',
    phase: NextPhase.f_break,
  );
}

// === Nested throw/catch ===

dynamic _nestedThrowCatch() {
  try {
    return _level1Exception();
  } on HHCtrlException catch (e) {
    return e.returnValue;
  }
}

dynamic _level1Exception() {
  try {
    return _level2Exception();
  } on HHCtrlException {
    rethrow;
  }
}

dynamic _level2Exception() {
  try {
    return _level3Exception();
  } on HHCtrlException {
    rethrow;
  }
}

dynamic _level3Exception() {
  throw HHCtrlException(nextPhase: NextPhase.f_break, returnValue: 'nested');
}

dynamic _nestedReturn() {
  return _level1Result();
}

dynamic _level1Result() {
  final result = _level2Result();
  if (result is _ControlResult && result.isControl) {
    return result;
  }
  return result;
}

dynamic _level2Result() {
  final result = _level3Result();
  if (result is _ControlResult && result.isControl) {
    return result;
  }
  return result;
}

dynamic _level3Result() {
  return _ControlResult(
    isControl: true,
    value: 'nested',
    phase: NextPhase.f_break,
  );
}

// === Hook chain simulation ===

dynamic _simulateHookChainException(int hookCount, double controlFlowRate) {
  try {
    for (var i = 0; i < hookCount; i++) {
      try {
        // Simulate some work
        final _ = DateTime.now().microsecond;

        // Some hooks trigger control flow
        if (i / hookCount < controlFlowRate) {
          throw HHCtrlException(
            nextPhase: NextPhase.f_break,
            returnValue: 'early_exit',
          );
        }
      } on HHCtrlException {
        rethrow;
      }
    }
    return 'completed';
  } on HHCtrlException catch (e) {
    return e.returnValue;
  }
}

dynamic _simulateHookChainResult(int hookCount, double controlFlowRate) {
  for (var i = 0; i < hookCount; i++) {
    // Simulate some work
    final _ = DateTime.now().microsecond;

    // Some hooks trigger control flow
    if (i / hookCount < controlFlowRate) {
      return _ControlResult(
        isControl: true,
        value: 'early_exit',
        phase: NextPhase.f_break,
      );
    }
  }
  return 'completed';
}

// === Different exception types ===

void _throwSpecificException(NextPhase phase) {
  try {
    throw HHCtrlException(
      nextPhase: phase,
      returnValue: 'test',
      runtimeMeta: {'key': 'value'},
    );
  } on HHCtrlException {
    // handled
  }
}

// === Metadata ===

void _throwWithMetadata() {
  try {
    throw HHCtrlException(
      nextPhase: NextPhase.f_break,
      returnValue: 'test',
      runtimeMeta: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'source': 'benchmark',
        'details': 'Some additional context',
      },
    );
  } on HHCtrlException {
    // handled
  }
}

void _throwWithoutMetadata() {
  try {
    throw HHCtrlException(nextPhase: NextPhase.f_break, returnValue: 'test');
  } on HHCtrlException {
    // handled
  }
}

// === Helper classes ===

class _ControlResult {
  final bool isControl;
  final dynamic value;
  final NextPhase phase;

  _ControlResult({required this.isControl, this.value, required this.phase});
}
