import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

/// Demonstrates TTL (Time-To-Live) expiration with cache scenarios.
/// Note: This uses basic timestamp checking rather than the TtlPlugin.
class TtlExpirationScenario extends Scenario {
  @override
  String get name => 'TTL Expiration';

  @override
  String get description => 'Time-to-live expiration with cache scenarios';

  @override
  IconData get icon => Icons.timer;

  @override
  List<String> get tags => ['ttl', 'expiration', 'cache'];

  @override
  Future<void> run(LogCallback log) async {
    log('━━━ TTL Expiration Demo ━━━', level: LogLevel.info);
    log('Simulating TTL with metadata timestamps (2-4 second TTLs)\n',
        level: LogLevel.data);

    final hive = await HHive.create('demo');
    const ttlSeconds = 3;

    // Scenario 1: Basic TTL with metadata
    log('1️⃣ Basic TTL (3 second expiry)', level: LogLevel.info);
    {
      final key = 'cache/session_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;

      await hive.put(
        key,
        {'userId': '12345', 'role': 'admin'},
        meta: {'createdAt': now, 'ttlSeconds': ttlSeconds},
      );
      log('  Stored session token (TTL: ${ttlSeconds}s)', level: LogLevel.data);

      // Check immediately
      var record = await hive.getWithMeta(key);
      var isExpired = _isExpired(record.meta, ttlSeconds);
      log('  Immediate check: ${!isExpired ? 'valid ✓' : 'expired ✗'}',
          level: !isExpired ? LogLevel.success : LogLevel.warning);

      // Wait and check again
      log('  Waiting 2 seconds...', level: LogLevel.data);
      await Future.delayed(const Duration(seconds: 2));

      record = await hive.getWithMeta(key);
      isExpired = _isExpired(record.meta, ttlSeconds);
      log('  After 2s: ${!isExpired ? 'valid ✓' : 'expired ✗'}',
          level: !isExpired ? LogLevel.success : LogLevel.warning);

      // Wait for expiration
      log('  Waiting 2 more seconds...', level: LogLevel.data);
      await Future.delayed(const Duration(seconds: 2));

      record = await hive.getWithMeta(key);
      isExpired = _isExpired(record.meta, ttlSeconds);
      log('  After 4s total: ${!isExpired ? 'valid ✓' : 'expired ✗'}',
          level: !isExpired ? LogLevel.success : LogLevel.warning);
    }

    // Scenario 2: Cache-Aside Pattern
    log('\n2️⃣ Cache-Aside Pattern', level: LogLevel.info);
    {
      final cacheKey = 'api/data_${DateTime.now().millisecondsSinceEpoch}';
      var fetchCount = 0;

      Future<Map<String, dynamic>> fetchFromApi() async {
        await Future.delayed(const Duration(milliseconds: 300));
        fetchCount++;
        return {
          'data': 'Fresh data fetch #$fetchCount',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      }

      Future<Map<String, dynamic>> getCachedOrFetch() async {
        final record = await hive.getWithMeta(cacheKey);
        if (record.value != null && !_isExpired(record.meta, 2)) {
          log('    Cache HIT', level: LogLevel.success);
          return record.value as Map<String, dynamic>;
        }
        log('    Cache MISS - fetching...', level: LogLevel.warning);
        final fresh = await fetchFromApi();
        await hive.put(cacheKey, fresh, meta: {
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'ttlSeconds': 2,
        });
        return fresh;
      }

      log('  Simulating cache-aside pattern:', level: LogLevel.data);

      // First call - cache miss
      log('  Request 1:', level: LogLevel.data);
      var result = await getCachedOrFetch();
      log('    Got: ${result['data']}', level: LogLevel.data);

      // Second call - cache hit
      log('  Request 2 (immediate):', level: LogLevel.data);
      result = await getCachedOrFetch();
      log('    Got: ${result['data']}', level: LogLevel.data);

      // Wait for expiration
      log('  Waiting 3 seconds for TTL expiration...', level: LogLevel.data);
      await Future.delayed(const Duration(seconds: 3));

      // Third call - cache miss again
      log('  Request 3 (after expiration):', level: LogLevel.data);
      result = await getCachedOrFetch();
      log('    Got: ${result['data']}', level: LogLevel.data);

      log('  Total API fetches: $fetchCount', level: LogLevel.info);
    }

    // Scenario 3: Multiple Items with Different TTLs
    log('\n3️⃣ Multiple Items Tracking', level: LogLevel.info);
    {
      final items = <String, int>{
        'short': 1,
        'medium': 3,
        'long': 5,
      };

      final baseTime = DateTime.now().millisecondsSinceEpoch;

      // Store items with different TTLs
      for (final entry in items.entries) {
        final key = 'ttl_test/${entry.key}_$baseTime';
        await hive.put(key, {'name': entry.key}, meta: {
          'createdAt': baseTime,
          'ttlSeconds': entry.value,
        });
      }
      log('  Stored 3 items with TTLs: short=1s, medium=3s, long=5s',
          level: LogLevel.data);

      // Check status over time
      for (var seconds = 0; seconds <= 5; seconds += 2) {
        if (seconds > 0) {
          log('  Waiting 2 seconds...', level: LogLevel.data);
          await Future.delayed(const Duration(seconds: 2));
        }

        final status = <String>[];
        for (final entry in items.entries) {
          final key = 'ttl_test/${entry.key}_$baseTime';
          final record = await hive.getWithMeta(key);
          final isValid = !_isExpired(record.meta, entry.value);
          status.add('${entry.key}=${isValid ? '✓' : '✗'}');
        }

        log('  T=${seconds}s: ${status.join(' ')}', level: LogLevel.data);
      }
    }

    log('\n━━━ TTL Expiration Demo Complete ━━━', level: LogLevel.success);
  }

  bool _isExpired(Map<String, dynamic>? meta, int ttlSeconds) {
    if (meta == null) return true;
    final createdAt = meta['createdAt'] as int?;
    if (createdAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = (now - createdAt) / 1000;
    return age > ttlSeconds;
  }
}
