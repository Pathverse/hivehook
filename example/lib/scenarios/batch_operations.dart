import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';
import '../main.dart';
import 'scenario.dart';

class BatchOperationsScenario extends Scenario {
  @override
  String get name => 'Batch Operations';

  @override
  String get description =>
      'Large-scale data operations, bulk inserts, and performance';

  @override
  IconData get icon => Icons.layers;

  @override
  List<String> get tags => ['performance', 'bulk', 'stress-test'];

  @override
  Future<void> run(LogCallback log) async {
    log('━━━ Batch Operations Demo ━━━', level: LogLevel.info);
    log('Testing large-scale data operations\n', level: LogLevel.data);

    final hive = await HHive.create('demo');
    final random = Random();
    final batchId = DateTime.now().millisecondsSinceEpoch;

    // Scenario 1: Bulk Insert
    log('1️⃣ Bulk Insert (50 products)', level: LogLevel.info);
    final categories = ['Electronics', 'Clothing', 'Home', 'Sports', 'Books'];
    final stopwatch = Stopwatch()..start();

    for (var i = 0; i < 50; i++) {
      final product = <String, dynamic>{
        'id': 'PROD-${i.toString().padLeft(4, '0')}',
        'name': 'Product ${i + 1}',
        'category': categories[random.nextInt(categories.length)],
        'price': (random.nextDouble() * 500 + 10).toStringAsFixed(2),
        'stock': random.nextInt(1000),
        'rating': (random.nextDouble() * 4 + 1).toStringAsFixed(1),
        'attributes': {
          'weight': '${random.nextInt(10) + 1}kg',
          'dimensions':
              '${random.nextInt(50) + 10}x${random.nextInt(50) + 10}x${random.nextInt(50) + 10}cm',
          'color': ['Red', 'Blue', 'Green', 'Black', 'White'][random.nextInt(5)],
        },
        'tags': List.generate(
          random.nextInt(3) + 1,
          (_) => ['popular', 'new', 'sale', 'featured'][random.nextInt(4)],
        ),
      };

      await hive.put('batch_$batchId/products/PROD-${i.toString().padLeft(4, '0')}',
          product);

      if ((i + 1) % 25 == 0) {
        log('  Inserted ${i + 1}/50 products...', level: LogLevel.data);
      }
    }

    stopwatch.stop();
    log('  ✓ Inserted 50 products in ${stopwatch.elapsedMilliseconds}ms',
        level: LogLevel.success);
    log('  Average: ${(stopwatch.elapsedMilliseconds / 50).toStringAsFixed(2)}ms per record',
        level: LogLevel.data);

    // Scenario 2: Bulk Read with Filtering
    log('\n2️⃣ Bulk Read & Filter', level: LogLevel.info);
    stopwatch.reset();
    stopwatch.start();

    final electronics = <Map<String, dynamic>>[];
    final highRated = <Map<String, dynamic>>[];
    final lowStock = <Map<String, dynamic>>[];

    for (var i = 0; i < 50; i++) {
      final key = 'batch_$batchId/products/PROD-${i.toString().padLeft(4, '0')}';
      final product = await hive.get(key) as Map<String, dynamic>?;

      if (product != null) {
        if (product['category'] == 'Electronics') {
          electronics.add(product);
        }
        if (double.parse(product['rating'] as String) >= 4.5) {
          highRated.add(product);
        }
        if ((product['stock'] as int) < 50) {
          lowStock.add(product);
        }
      }
    }

    stopwatch.stop();
    log('  Read & filtered 50 records in ${stopwatch.elapsedMilliseconds}ms',
        level: LogLevel.data);
    log('  Results:', level: LogLevel.info);
    log('    Electronics: ${electronics.length} items', level: LogLevel.data);
    log('    High rated (≥4.5): ${highRated.length} items', level: LogLevel.data);
    log('    Low stock (<50): ${lowStock.length} items', level: LogLevel.data);

    // Scenario 3: Aggregation
    log('\n3️⃣ Aggregation', level: LogLevel.info);
    stopwatch.reset();
    stopwatch.start();

    final categoryStats = <String, Map<String, dynamic>>{};
    var totalStock = 0;
    var totalValue = 0.0;

    for (var i = 0; i < 50; i++) {
      final key = 'batch_$batchId/products/PROD-${i.toString().padLeft(4, '0')}';
      final product = await hive.get(key) as Map<String, dynamic>?;

      if (product != null) {
        final category = product['category'] as String;
        final price = double.parse(product['price'] as String);
        final stock = product['stock'] as int;

        categoryStats[category] ??= {'count': 0, 'totalValue': 0.0, 'totalStock': 0};

        final stats = categoryStats[category]!;
        stats['count'] = (stats['count'] as int) + 1;
        stats['totalValue'] = (stats['totalValue'] as double) + (price * stock);
        stats['totalStock'] = (stats['totalStock'] as int) + stock;

        totalStock += stock;
        totalValue += price * stock;
      }
    }

    stopwatch.stop();
    log('  Aggregated 50 records in ${stopwatch.elapsedMilliseconds}ms',
        level: LogLevel.data);

    log('\n  Category Statistics:', level: LogLevel.info);
    for (final entry in categoryStats.entries) {
      final stats = entry.value;
      log('    ${entry.key}: ${stats['count']} items, ${stats['totalStock']} stock',
          level: LogLevel.data);
    }

    log('\n  Grand Totals:', level: LogLevel.info);
    log('    Total Stock: $totalStock units', level: LogLevel.data);
    log('    Total Inventory Value: \$${totalValue.toStringAsFixed(2)}',
        level: LogLevel.data);

    // Scenario 4: Deep Nesting Stress Test
    log('\n4️⃣ Stress Test (Deep Nesting)', level: LogLevel.info);

    Map<String, dynamic> createNestedMap(int depth) {
      if (depth == 0) {
        return {'value': random.nextInt(1000)};
      }
      return {
        'level': depth,
        'data': List.generate(3, (i) => 'item_$i'),
        'child': createNestedMap(depth - 1),
        'metadata': {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'random': random.nextDouble(),
        },
      };
    }

    final deepObject = createNestedMap(8); // 8 levels deep
    final jsonSize = utf8.encode(jsonEncode(deepObject)).length;

    log('  Created object with 8 nesting levels', level: LogLevel.data);
    log('  JSON size: ${(jsonSize / 1024).toStringAsFixed(2)} KB', level: LogLevel.data);

    stopwatch.reset();
    stopwatch.start();
    await hive.put('batch_$batchId/stress/deep_nested', deepObject);
    final writeTime = stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    stopwatch.start();
    final retrieved =
        await hive.get('batch_$batchId/stress/deep_nested') as Map<String, dynamic>;
    final readTime = stopwatch.elapsedMilliseconds;

    log('  Write time: ${writeTime}ms', level: LogLevel.data);
    log('  Read time: ${readTime}ms', level: LogLevel.data);

    // Verify deepest level
    var current = retrieved;
    for (var i = 0; i < 8; i++) {
      current = current['child'] as Map<String, dynamic>;
    }
    log('  ✓ Deepest value retrieved: ${current['value']}', level: LogLevel.success);

    // Scenario 5: Bulk Delete
    log('\n5️⃣ Bulk Delete', level: LogLevel.info);
    stopwatch.reset();
    stopwatch.start();

    var deleted = 0;
    for (var i = 0; i < 50; i++) {
      final key = 'batch_$batchId/products/PROD-${i.toString().padLeft(4, '0')}';
      await hive.delete(key);
      deleted++;
    }
    // Also delete the stress test
    await hive.delete('batch_$batchId/stress/deep_nested');
    deleted++;

    stopwatch.stop();
    log('  ✓ Deleted $deleted items in ${stopwatch.elapsedMilliseconds}ms',
        level: LogLevel.success);

    log('\n━━━ Batch Operations Demo Complete ━━━', level: LogLevel.success);
  }
}
