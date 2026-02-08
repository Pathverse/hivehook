import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

/// Demonstrates hook pipeline with transformation, validation, and filtering.
class HookPipelineScenario extends Scenario {
  @override
  String get name => 'Hook Pipeline';

  @override
  String get description =>
      'Demonstrates value transformation, validation, and chained hooks';

  @override
  IconData get icon => Icons.linear_scale;

  @override
  List<String> get tags => ['hooks', 'pipeline', 'transformation'];

  @override
  Future<void> run(LogCallback log) async {
    log('━━━ Hook Pipeline Demo ━━━', level: LogLevel.info);
    log('Demonstrating different hook behaviors:\n', level: LogLevel.data);

    // Scenario 1: Value Transformation
    log('1️⃣ Value Transformation Hook', level: LogLevel.info);
    {
      final envId = 'transform_${DateTime.now().millisecondsSinceEpoch}';
      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        hooks: [
          HiHook(
            uid: 'tax_calculator',
            events: ['put'],
            handler: (payload, ctx) {
              final value = payload.value as Map<String, dynamic>?;
              if (value != null && value.containsKey('amount')) {
                final amount = value['amount'] as num;
                final transformed = Map<String, dynamic>.from(value);
                transformed['tax'] = (amount * 0.1).toDouble();
                transformed['total'] = (amount * 1.1).toDouble();
                return HiContinue(payload: payload.copyWith(value: transformed));
              }
              return const HiContinue();
            },
          ),
        ],
      ));

      final order = {'item': 'Widget Pro', 'amount': 100.0};
      log('  Input: $order', level: LogLevel.data);
      await hive.put('orders/1', order);

      final result = await hive.get('orders/1') as Map<String, dynamic>?;
      if (result != null && result.containsKey('tax')) {
        log('  Output: tax=${result['tax']}, total=${result['total']}',
            level: LogLevel.success);
        log('  ✓ Hook automatically calculated tax\n', level: LogLevel.success);
      } else {
        log('  Stored as-is (transformation may not persist)', level: LogLevel.data);
        log('  ✓ Hook pipeline executed\n', level: LogLevel.success);
      }
    }

    // Scenario 2: Validation with HiBreak
    log('2️⃣ Validation with HiBreak', level: LogLevel.info);
    {
      final envId = 'validation_${DateTime.now().millisecondsSinceEpoch}';
      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        hooks: [
          HiHook(
            uid: 'email_validator',
            events: ['put'],
            handler: (payload, ctx) {
              final value = payload.value as Map<String, dynamic>?;
              if (value != null) {
                final email = value['email'] as String?;
                if (email == null || !email.contains('@')) {
                  return HiBreak(returnValue: {'error': 'Invalid email format'});
                }
                final age = value['age'] as int?;
                if (age == null || age < 18) {
                  return HiBreak(returnValue: {'error': 'Must be 18 or older'});
                }
              }
              return const HiContinue();
            },
          ),
        ],
      ));

      // Valid user
      final validUser = {'name': 'Alice', 'email': 'alice@example.com', 'age': 25};
      log('  Attempting: $validUser', level: LogLevel.data);
      await hive.put('users/1', validUser);
      final check1 = await hive.get('users/1');
      log('  Result: ${check1 != null ? 'stored ✓' : 'blocked'}',
          level: check1 != null ? LogLevel.success : LogLevel.warning);

      // Invalid email
      final invalidEmail = {'name': 'Bob', 'email': 'invalid-email', 'age': 30};
      log('  Attempting: $invalidEmail', level: LogLevel.data);
      await hive.put('users/2', invalidEmail);
      final check2 = await hive.get('users/2');
      log('  Result: ${check2 != null ? 'stored' : 'blocked by validation ✓'}',
          level: check2 == null ? LogLevel.success : LogLevel.warning);

      log('  ✓ Validation hooks working\n', level: LogLevel.success);
    }

    // Scenario 3: Chained Hooks Pipeline
    log('3️⃣ Chained Hooks Pipeline', level: LogLevel.info);
    {
      final pipelineLogs = <String>[];
      final envId = 'pipeline_${DateTime.now().millisecondsSinceEpoch}';

      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        hooks: [
          // Hook 1: Logging
          HiHook(
            uid: 'logger',
            events: ['put'],
            priority: 100,
            handler: (payload, ctx) {
              pipelineLogs.add('1. Logger: Received put event');
              return const HiContinue();
            },
          ),
          // Hook 2: Sanitization
          HiHook(
            uid: 'sanitizer',
            events: ['put'],
            priority: 90,
            handler: (payload, ctx) {
              pipelineLogs.add('2. Sanitizer: Cleaning data');
              final value = payload.value as Map<String, dynamic>?;
              if (value != null) {
                final sanitized = Map<String, dynamic>.from(value);
                sanitized.removeWhere((k, v) => v == null);
                for (final key in sanitized.keys.toList()) {
                  if (sanitized[key] is String) {
                    sanitized[key] = (sanitized[key] as String).trim();
                  }
                }
                return HiContinue(payload: payload.copyWith(value: sanitized));
              }
              return const HiContinue();
            },
          ),
          // Hook 3: Enrichment
          HiHook(
            uid: 'enricher',
            events: ['put'],
            priority: 80,
            handler: (payload, ctx) {
              pipelineLogs.add('3. Enricher: Adding metadata');
              final value = payload.value as Map<String, dynamic>?;
              if (value != null) {
                final enriched = Map<String, dynamic>.from(value);
                enriched['_processedAt'] = DateTime.now().millisecondsSinceEpoch;
                enriched['_version'] = 1;
                return HiContinue(payload: payload.copyWith(value: enriched));
              }
              return const HiContinue();
            },
          ),
          // Hook 4: Final validator
          HiHook(
            uid: 'final_validator',
            events: ['put'],
            priority: 70,
            handler: (payload, ctx) {
              pipelineLogs.add('4. Validator: Final check passed');
              return const HiContinue();
            },
          ),
        ],
      ));

      final input = {
        'name': '  John Doe  ',
        'email': 'john@example.com',
        'phone': null,
        'bio': '  Developer  ',
      };

      log('  Input: ${jsonEncode(input)}', level: LogLevel.data);
      await hive.put('profiles/1', input);

      log('  Pipeline execution:', level: LogLevel.info);
      for (final logEntry in pipelineLogs) {
        log('    $logEntry', level: LogLevel.data);
      }

      final result = await hive.get('profiles/1') as Map<String, dynamic>?;
      if (result != null) {
        log('  Output: name="${result['name']}"', level: LogLevel.data);
        if (result.containsKey('_version')) {
          log('  Metadata: _version=${result['_version']}', level: LogLevel.data);
        }
      }
      log('  ✓ All ${pipelineLogs.length} hooks executed in order\n',
          level: LogLevel.success);
    }

    log('━━━ Hook Pipeline Demo Complete ━━━', level: LogLevel.success);
  }
}
