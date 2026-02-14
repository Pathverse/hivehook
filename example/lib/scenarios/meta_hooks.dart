import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

/// Demonstrates meta hooks for metadata transformation and encryption.
class MetaHooksScenario extends Scenario {
  @override
  String get name => 'Meta Hooks';

  @override
  String get description =>
      'Demonstrates metadata hooks for encryption, TTL, and audit trails';

  @override
  IconData get icon => Icons.security;

  @override
  List<String> get tags => ['meta', 'hooks', 'encryption', 'audit'];

  @override
  Future<void> run(LogCallback log) async {
    log('━━━ Meta Hooks Demo ━━━', level: LogLevel.info);
    log('Demonstrating metadata transformation with hooks:\n',
        level: LogLevel.data);

    // Scenario 1: Meta Encryption Hook
    log('1️⃣ Metadata Encryption', level: LogLevel.info);
    {
      final envId = 'meta_encrypt_${DateTime.now().millisecondsSinceEpoch}';
      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        withMeta: true,
        metaHooks: [
          // Encrypt sensitive meta on write
          HiHook(
            uid: 'meta_encryptor',
            events: ['writeMeta'],
            handler: (payload, ctx) {
              // For meta hooks, meta is passed as payload.value
              final meta = payload.value as Map<String, dynamic>?;
              if (meta != null && meta.containsKey('apiKey')) {
                final encrypted = Map<String, dynamic>.from(meta);
                // Simple obfuscation for demo (use real encryption in production!)
                encrypted['apiKey'] = base64Encode(
                    utf8.encode(encrypted['apiKey'] as String));
                encrypted['_encrypted'] = true;
                log('    📝 Encrypting apiKey in metadata', level: LogLevel.data);
                return HiContinue(payload: payload.copyWith(value: encrypted));
              }
              return const HiContinue();
            },
          ),
          // Decrypt on read
          HiHook(
            uid: 'meta_decryptor',
            events: ['readMeta'],
            handler: (payload, ctx) {
              // For meta hooks, meta is passed as payload.value
              final meta = payload.value as Map<String, dynamic>?;
              if (meta != null && meta['_encrypted'] == true) {
                final decrypted = Map<String, dynamic>.from(meta);
                decrypted['apiKey'] =
                    utf8.decode(base64Decode(decrypted['apiKey'] as String));
                decrypted.remove('_encrypted');
                log('    🔓 Decrypting apiKey from metadata',
                    level: LogLevel.data);
                return HiContinue(payload: payload.copyWith(value: decrypted));
              }
              return const HiContinue();
            },
          ),
        ],
      ));

      final sensitiveData = {'userId': 'user123', 'settings': 'premium'};
      final meta = {'apiKey': 'SECRET_API_KEY_12345', 'source': 'mobile_app'};

      log('  Storing with sensitive metadata:', level: LogLevel.data);
      log('    value: ${jsonEncode(sensitiveData)}', level: LogLevel.data);
      log('    meta: ${jsonEncode(meta)}', level: LogLevel.data);

      await hive.put('secure/config', sensitiveData, meta: meta);

      log('  Reading back:', level: LogLevel.data);
      final result = await hive.getWithMeta('secure/config');
      final resultMeta = result.meta;
      log('    meta.apiKey: ${resultMeta?['apiKey']}', level: LogLevel.success);
      log('  ✓ Metadata encrypted at rest, decrypted on read\n',
          level: LogLevel.success);
    }

    // Scenario 2: Meta Audit Trail
    log('2️⃣ Metadata Audit Trail', level: LogLevel.info);
    {
      final auditLog = <String>[];
      final envId = 'meta_audit_${DateTime.now().millisecondsSinceEpoch}';
      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        withMeta: true,
        metaHooks: [
          HiHook(
            uid: 'meta_audit',
            events: ['readMeta', 'writeMeta', 'deleteMeta'],
            handler: (payload, ctx) {
              final key = payload.key;
              final timestamp = DateTime.now().toIso8601String();
              auditLog.add('[$timestamp] meta-op on $key');
              return const HiContinue();
            },
          ),
        ],
      ));

      log('  Performing operations...', level: LogLevel.data);
      await hive.put('users/1', {'name': 'Alice'}, meta: {'role': 'admin'});
      await hive.get('users/1');
      await hive.putMeta('users/1', {'role': 'super_admin', 'promoted': true});
      await hive.getMeta('users/1');
      await hive.delete('users/1');

      log('  Audit log:', level: LogLevel.info);
      for (final entry in auditLog) {
        log('    $entry', level: LogLevel.data);
      }
      log('  ✓ All metadata operations logged\n', level: LogLevel.success);
    }

    // Scenario 3: TTL Invalidation via Meta-First Pattern
    log('3️⃣ TTL with Meta-First Pattern', level: LogLevel.info);
    {
      var valueReadCount = 0;
      var metaReadCount = 0;
      final envId = 'meta_ttl_${DateTime.now().millisecondsSinceEpoch}';

      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        withMeta: true,
        hooks: [
          HiHook(
            uid: 'value_tracker',
            events: ['read'],
            handler: (payload, ctx) {
              valueReadCount++;
              return const HiContinue();
            },
          ),
        ],
        metaHooks: [
          HiHook(
            uid: 'ttl_checker',
            events: ['readMeta'],
            handler: (payload, ctx) {
              metaReadCount++;
              // For meta hooks, metadata is passed as payload.value
              final meta = payload.value as Map<String, dynamic>?;
              if (meta != null) {
                final createdAt = meta['createdAt'] as int?;
                final ttlMs = meta['ttlMs'] as int?;
                if (createdAt != null && ttlMs != null) {
                  final now = DateTime.now().millisecondsSinceEpoch;
                  if (now - createdAt > ttlMs) {
                    log('    ⏰ TTL expired - returning null',
                        level: LogLevel.warning);
                    return HiBreak(returnValue: null);
                  }
                }
              }
              return const HiContinue();
            },
          ),
        ],
      ));

      // Store with short TTL
      await hive.put(
        'cache/temp',
        {'data': 'Expensive computed value'},
        meta: {
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'ttlMs': 1500, // 1.5 seconds
        },
      );

      log('  Stored value with 1.5s TTL', level: LogLevel.data);

      // Read immediately - should work
      log('  Reading immediately...', level: LogLevel.data);
      var result = await hive.get('cache/temp');
      log('    Result: ${result != null ? 'got value' : 'null'}',
          level: result != null ? LogLevel.success : LogLevel.warning);

      // Wait and read again
      log('  Waiting 2 seconds...', level: LogLevel.data);
      await Future.delayed(const Duration(seconds: 2));

      log('  Reading after TTL...', level: LogLevel.data);
      result = await hive.get('cache/temp');
      log('    Result: ${result != null ? 'got value' : 'null (expired)'}',
          level: result == null ? LogLevel.success : LogLevel.warning);

      log('  Stats: Meta reads=$metaReadCount, Value reads=$valueReadCount',
          level: LogLevel.data);
      log('  ✓ Meta-first pattern enables efficient TTL checks\n',
          level: LogLevel.success);
    }

    // Scenario 4: Separate Meta Operations
    log('4️⃣ Standalone Meta Operations', level: LogLevel.info);
    {
      final envId = 'meta_ops_${DateTime.now().millisecondsSinceEpoch}';
      final hive = await HHive.createFromConfig(HiveConfig(
        env: envId,
        type: HiveBoxType.box,
        withMeta: true,
      ));

      // Store initial data
      await hive.put(
        'items/1',
        {'name': 'Product', 'price': 99.99},
        meta: {'views': 0, 'lastViewed': null},
      );

      log('  Initial state:', level: LogLevel.data);
      var meta = await hive.getMeta('items/1');
      log('    meta: ${jsonEncode(meta)}', level: LogLevel.data);

      // Update only meta (e.g., increment view count)
      log('  Incrementing view count...', level: LogLevel.data);
      final views = (meta?['views'] as int? ?? 0) + 1;
      await hive.putMeta('items/1', {
        'views': views,
        'lastViewed': DateTime.now().toIso8601String(),
      });

      // Read back
      meta = await hive.getMeta('items/1');
      log('    Updated meta: ${jsonEncode(meta)}', level: LogLevel.data);
      log('  ✓ Meta updated without touching value\n', level: LogLevel.success);
    }

    log('━━━ Meta Hooks Demo Complete ━━━', level: LogLevel.success);
  }
}
