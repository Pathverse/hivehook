import 'package:flutter/material.dart';
import 'package:hivehook/hivehook.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HiveHook Web Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late HHive ttlHive;
  late HHive lruHive;
  late HHive customHive;
  late HHive comboHive;
  final List<String> auditLog = [];
  final List<String> ttlOutput = [];
  final List<String> lruOutput = [];
  final List<String> customOutput = [];
  final List<String> comboOutput = [];

  final ttlKeyController = TextEditingController(text: 'session');
  final ttlValueController = TextEditingController(text: 'user123');
  final ttlSecondsController = TextEditingController(text: '5');

  final lruKeyController = TextEditingController(text: 'item1');
  final lruValueController = TextEditingController(text: 'data1');

  final customKeyController = TextEditingController(text: 'user');
  final customValueController = TextEditingController(text: 'John Doe');

  final comboKeyController = TextEditingController(text: 'combo1');
  final comboValueController = TextEditingController(text: 'test data');

  @override
  void initState() {
    super.initState();
    _setupDemos();
  }

  Future<void> _setupDemos() async {
    // Step 1: Define all configs FIRST (before initialize)
    // TTL Demo
    final ttlPlugin = createTTLPlugin(defaultTTLSeconds: 5);
    final ttlConfig = HHConfig(env: 'ttl_demo', usesMeta: true);
    ttlConfig.installPlugin(ttlPlugin);
    final finalizedTtlConfig = ttlConfig.finalize();

    // LRU Demo
    final lruPlugin = createLRUPlugin(maxSize: 3);
    final lruConfig = HHConfig(env: 'lru_demo', usesMeta: true);
    lruConfig.installPlugin(lruPlugin);
    final finalizedLruConfig = lruConfig.finalize();

    // Custom Hooks Demo
    final customConfig = HHConfig(
      env: 'custom_demo',
      usesMeta: true,
      actionHooks: [
        HActionHook(
          latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
          action: (ctx) async {
            if (ctx.payload.value == null ||
                ctx.payload.value.toString().isEmpty) {
              throw ArgumentError('Value cannot be empty');
            }
          },
        ),
        HActionHook(
          latches: [
            HHLatch(triggerType: TriggerType.valueWrite, isPost: true),
            HHLatch(triggerType: TriggerType.valueRead, isPost: true),
          ],
          action: (ctx) async {
            final timestamp = DateTime.now().toIso8601String();
            final operation = ctx.payload.key != null
                ? 'Operation on key: ${ctx.payload.key}'
                : 'Operation';
            auditLog.add('[$timestamp] $operation');
          },
        ),
      ],
    );
    final finalizedCustomConfig = customConfig.finalize();

    // Combined Demo
    final ttlPlugin2 = createTTLPlugin(defaultTTLSeconds: 10);
    final lruPlugin2 = createLRUPlugin(maxSize: 5);
    final comboConfig = HHConfig(
      env: 'combo_demo',
      usesMeta: true,
      actionHooks: [
        HActionHook(
          latches: [HHLatch.pre(triggerType: TriggerType.valueWrite)],
          action: (ctx) async {
            if (ctx.payload.value == null ||
                ctx.payload.value.toString().isEmpty) {
              throw ArgumentError('Value cannot be empty');
            }
          },
        ),
      ],
    );
    comboConfig.installPlugin(ttlPlugin2);
    comboConfig.installPlugin(lruPlugin2);
    final finalizedComboConfig = comboConfig.finalize();

    // Step 2: Initialize HHiveCore (now it knows about all boxes)
    await HHiveCore.initialize();

    // Step 3: Create HHive instances
    ttlHive = HHive(config: finalizedTtlConfig);
    lruHive = HHive(config: finalizedLruConfig);
    customHive = HHive(config: finalizedCustomConfig);
    comboHive = HHive(config: finalizedComboConfig);
  }

  void _addOutput(List<String> list, String message) {
    setState(() {
      list.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🚀 HiveHook Web Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Run All Scenarios',
            onPressed: _runAllScenarios,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildScenarioButtons(),
            const SizedBox(height: 20),
            _buildTTLSection(),
            const SizedBox(height: 20),
            _buildLRUSection(),
            const SizedBox(height: 20),
            _buildCustomSection(),
            const SizedBox(height: 20),
            _buildComboSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioButtons() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎬 Demo Scenarios',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click any scenario to see it in action!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _runTTLScenario,
                  icon: const Icon(Icons.timer),
                  label: const Text('TTL Expiration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _runLRUScenario,
                  icon: const Icon(Icons.storage),
                  label: const Text('LRU Eviction'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _runValidationScenario,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Validation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _runComboScenario,
                  icon: const Icon(Icons.layers),
                  label: const Text('Combined'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllScenarios() async {
    _clearAll();
    await Future.delayed(const Duration(milliseconds: 500));
    await _runTTLScenario();
    await Future.delayed(const Duration(milliseconds: 1000));
    await _runLRUScenario();
    await Future.delayed(const Duration(milliseconds: 1000));
    await _runValidationScenario();
    await Future.delayed(const Duration(milliseconds: 1000));
    await _runComboScenario();
  }

  Future<void> _runTTLScenario() async {
    setState(() => ttlOutput.clear());
    _addOutput(ttlOutput, '🎬 Starting TTL Scenario...');

    // Store data with 3 second TTL
    await ttlHive.put('demo_key', 'demo_value', meta: {'ttl': '3'});
    _addOutput(ttlOutput, '✅ Stored: demo_key = demo_value (TTL: 3s)');

    await Future.delayed(const Duration(milliseconds: 500));

    // Read immediately - should succeed
    var value = await ttlHive.get('demo_key');
    _addOutput(ttlOutput, '✅ Read immediately: $value');

    await Future.delayed(const Duration(milliseconds: 500));

    // Wait and read again - should succeed
    _addOutput(ttlOutput, '⏳ Waiting 1 second...');
    await Future.delayed(const Duration(seconds: 1));
    value = await ttlHive.get('demo_key');
    _addOutput(ttlOutput, '✅ After 1s: $value (still alive)');

    // Wait for expiration
    _addOutput(ttlOutput, '⏳ Waiting 3 more seconds for expiration...');
    await Future.delayed(const Duration(seconds: 3));

    // Try to read - should be expired
    value = await ttlHive.get('demo_key');
    if (value == null) {
      _addOutput(ttlOutput, '⏰ After 4s total: EXPIRED (as expected!)');
    } else {
      _addOutput(ttlOutput, '❌ Still exists: $value');
    }

    _addOutput(ttlOutput, '✨ Scenario complete!');
  }

  Future<void> _runLRUScenario() async {
    setState(() => lruOutput.clear());
    _addOutput(lruOutput, '🎬 Starting LRU Scenario (max 3 items)...');

    // Add 3 items (fill cache)
    await lruHive.put('item1', 'data1');
    _addOutput(lruOutput, '✅ Added: item1 = data1');
    await Future.delayed(const Duration(milliseconds: 300));

    await lruHive.put('item2', 'data2');
    _addOutput(lruOutput, '✅ Added: item2 = data2');
    await Future.delayed(const Duration(milliseconds: 300));

    await lruHive.put('item3', 'data3');
    _addOutput(lruOutput, '✅ Added: item3 = data3');
    _addOutput(lruOutput, '📋 Cache is now FULL (3/3)');
    await Future.delayed(const Duration(milliseconds: 500));

    // Access item2 to make it recently used
    await lruHive.get('item2');
    _addOutput(lruOutput, '👆 Accessed item2 (making it recently used)');
    await Future.delayed(const Duration(milliseconds: 500));

    // Add 4th item - should evict item1 (least recently used)
    await lruHive.put('item4', 'data4');
    _addOutput(lruOutput, '➕ Added: item4 = data4');
    _addOutput(lruOutput, '🗑️  item1 should be evicted (LRU)');
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify eviction
    final item1 = await lruHive.get('item1');
    final item2 = await lruHive.get('item2');
    final item3 = await lruHive.get('item3');
    final item4 = await lruHive.get('item4');

    _addOutput(lruOutput, '');
    _addOutput(lruOutput, '📊 Final state:');
    _addOutput(
      lruOutput,
      item1 == null ? '  ❌ item1: EVICTED ✓' : '  ❌ item1: Still exists',
    );
    _addOutput(
      lruOutput,
      item2 != null ? '  ✅ item2: $item2 ✓' : '  ❌ item2: Missing',
    );
    _addOutput(
      lruOutput,
      item3 != null ? '  ✅ item3: $item3 ✓' : '  ❌ item3: Missing',
    );
    _addOutput(
      lruOutput,
      item4 != null ? '  ✅ item4: $item4 ✓' : '  ❌ item4: Missing',
    );

    _addOutput(lruOutput, '✨ Scenario complete!');
  }

  Future<void> _runValidationScenario() async {
    setState(() => customOutput.clear());
    _addOutput(customOutput, '🎬 Starting Validation Scenario...');

    // Test 1: Valid data
    try {
      await customHive.put('user1', 'Alice');
      _addOutput(customOutput, '✅ Valid data accepted: user1 = Alice');
      if (auditLog.isNotEmpty) {
        _addOutput(customOutput, '📝 ${auditLog.last}');
      }
    } catch (e) {
      _addOutput(customOutput, '❌ Unexpected error: $e');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Test 2: Empty value - should fail
    try {
      await customHive.put('user2', '');
      _addOutput(customOutput, '❌ Empty value should have been rejected!');
    } catch (e) {
      _addOutput(customOutput, '✅ Empty value rejected (as expected): $e');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Test 3: Read and log
    final value = await customHive.get('user1');
    _addOutput(customOutput, '✅ Read: user1 = $value');
    if (auditLog.isNotEmpty) {
      _addOutput(customOutput, '📝 ${auditLog.last}');
    }

    _addOutput(customOutput, '');
    _addOutput(customOutput, '📊 Audit log has ${auditLog.length} entries');
    _addOutput(customOutput, '✨ Scenario complete!');
  }

  Future<void> _runComboScenario() async {
    setState(() => comboOutput.clear());
    _addOutput(comboOutput, '🎬 Starting Combined Scenario...');
    _addOutput(comboOutput, '(TTL: 10s, LRU: max 5, Validation)');
    _addOutput(comboOutput, '');

    // Add items quickly
    for (int i = 1; i <= 6; i++) {
      try {
        await comboHive.put('item$i', 'data$i');
        _addOutput(comboOutput, '✅ Added: item$i = data$i');
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        _addOutput(comboOutput, '❌ Error: $e');
      }
    }

    _addOutput(comboOutput, '');
    _addOutput(comboOutput, '📋 Result: 6 items added, cache max is 5');
    _addOutput(comboOutput, '🗑️  item1 should be evicted (LRU)');

    await Future.delayed(const Duration(milliseconds: 500));

    // Verify
    final item1 = await comboHive.get('item1');
    final item6 = await comboHive.get('item6');

    _addOutput(comboOutput, '');
    _addOutput(
      comboOutput,
      '✓ item1: ${item1 == null ? "EVICTED" : "Still exists"}',
    );
    _addOutput(comboOutput, '✓ item6: ${item6 != null ? "EXISTS" : "Missing"}');

    _addOutput(comboOutput, '');
    _addOutput(comboOutput, '⏰ All items will expire in 10 seconds');
    _addOutput(comboOutput, '✨ Scenario complete!');
  }

  void _clearAll() {
    setState(() {
      ttlOutput.clear();
      lruOutput.clear();
      customOutput.clear();
      comboOutput.clear();
      auditLog.clear();
    });
  }

  Widget _buildTTLSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏰ TTL Plugin - Auto Expiration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data automatically expires after the TTL period. Default is 5 seconds.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ttlKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ttlValueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: ttlSecondsController,
                    decoration: const InputDecoration(
                      labelText: 'TTL (s)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await ttlHive.put(
                        ttlKeyController.text,
                        ttlValueController.text,
                        meta: {'ttl': ttlSecondsController.text},
                      );
                      _addOutput(
                        ttlOutput,
                        '✅ Stored: ${ttlKeyController.text} = ${ttlValueController.text} (expires in ${ttlSecondsController.text}s)',
                      );
                    } catch (e) {
                      _addOutput(ttlOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Set with TTL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final value = await ttlHive.get(ttlKeyController.text);
                      if (value == null) {
                        _addOutput(
                          ttlOutput,
                          '⏰ Key "${ttlKeyController.text}" expired or not found',
                        );
                      } else {
                        final meta = await ttlHive.getMeta(
                          ttlKeyController.text,
                        );
                        _addOutput(
                          ttlOutput,
                          '✅ Read: ${ttlKeyController.text} = $value (TTL: ${meta?['ttl']}s)',
                        );
                      }
                    } catch (e) {
                      _addOutput(ttlOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Read'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      ttlOutput.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: ttlOutput.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      ttlOutput[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLRUSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💾 LRU Plugin - Cache Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'LRU cache with max size of 3 items. Evicts least recently used when full.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: lruKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lruValueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await lruHive.put(
                        lruKeyController.text,
                        lruValueController.text,
                      );
                      _addOutput(
                        lruOutput,
                        '✅ Added: ${lruKeyController.text} = ${lruValueController.text}',
                      );
                      await Future.delayed(const Duration(milliseconds: 100));
                      await _lruListAll();
                    } catch (e) {
                      _addOutput(lruOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Add to Cache'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final value = await lruHive.get(lruKeyController.text);
                      if (value == null) {
                        _addOutput(
                          lruOutput,
                          '⚠️ Key "${lruKeyController.text}" not found (may have been evicted)',
                        );
                      } else {
                        _addOutput(
                          lruOutput,
                          '✅ Read: ${lruKeyController.text} = $value',
                        );
                      }
                    } catch (e) {
                      _addOutput(lruOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Read'),
                ),
                ElevatedButton(
                  onPressed: _lruListAll,
                  child: const Text('List All'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      lruOutput.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: lruOutput.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      lruOutput[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lruListAll() async {
    try {
      final cacheIndexMeta = await lruHive.getMeta('_lru_cache_keys');
      final keysString = cacheIndexMeta?['keys'] as String?;

      if (keysString == null || keysString.isEmpty) {
        _addOutput(lruOutput, 'ℹ️ Cache is empty');
        return;
      }

      final keys = keysString.split(',').where((k) => k.isNotEmpty).toList();
      _addOutput(lruOutput, '📋 Cache contents (${keys.length}/3 items):');

      for (var key in keys) {
        final value = await lruHive.get(key);
        _addOutput(lruOutput, '  • $key = $value');
      }
    } catch (e) {
      _addOutput(lruOutput, '❌ Error: $e');
    }
  }

  Widget _buildCustomSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔧 Custom Hooks - Validation & Logging',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pre-hook validates data (no empty values), post-hook logs operations.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: customValueController,
                    decoration: const InputDecoration(
                      labelText: 'Value (try empty!)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await customHive.put(
                        customKeyController.text,
                        customValueController.text,
                      );
                      _addOutput(
                        customOutput,
                        '✅ Validation passed! Stored: ${customKeyController.text} = ${customValueController.text}',
                      );
                      if (auditLog.isNotEmpty) {
                        _addOutput(customOutput, '📝 ${auditLog.last}');
                      }
                    } catch (e) {
                      _addOutput(customOutput, '❌ Validation failed: $e');
                    }
                  },
                  child: const Text('Write'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final value = await customHive.get(
                        customKeyController.text,
                      );
                      if (value == null) {
                        _addOutput(
                          customOutput,
                          '⚠️ Key "${customKeyController.text}" not found',
                        );
                      } else {
                        _addOutput(
                          customOutput,
                          '✅ Read: ${customKeyController.text} = $value',
                        );
                      }
                      if (auditLog.isNotEmpty) {
                        _addOutput(customOutput, '📝 ${auditLog.last}');
                      }
                    } catch (e) {
                      _addOutput(customOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Read'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      customOutput.clear();
                      auditLog.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: customOutput.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      customOutput[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComboSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔀 Combined Plugins - TTL + LRU + Validation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All plugins working together! TTL (10s), LRU (max 5), validation.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: comboKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: comboValueController,
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await comboHive.put(
                        comboKeyController.text,
                        comboValueController.text,
                      );
                      _addOutput(
                        comboOutput,
                        '✅ Stored: ${comboKeyController.text} = ${comboValueController.text} (TTL: 10s, LRU tracked)',
                      );
                    } catch (e) {
                      _addOutput(comboOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Add Item'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final value = await comboHive.get(
                        comboKeyController.text,
                      );
                      if (value == null) {
                        _addOutput(
                          comboOutput,
                          '⚠️ Key "${comboKeyController.text}" not found (expired or evicted)',
                        );
                      } else {
                        final meta = await comboHive.getMeta(
                          comboKeyController.text,
                        );
                        _addOutput(
                          comboOutput,
                          '✅ Read: ${comboKeyController.text} = $value (TTL: ${meta?['ttl']}s)',
                        );
                      }
                    } catch (e) {
                      _addOutput(comboOutput, '❌ Error: $e');
                    }
                  },
                  child: const Text('Read'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      comboOutput.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: comboOutput.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      comboOutput[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ttlKeyController.dispose();
    ttlValueController.dispose();
    ttlSecondsController.dispose();
    lruKeyController.dispose();
    lruValueController.dispose();
    customKeyController.dispose();
    customValueController.dispose();
    comboKeyController.dispose();
    comboValueController.dispose();
    super.dispose();
  }
}
