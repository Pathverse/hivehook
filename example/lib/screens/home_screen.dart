import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/test_category.dart';
import '../widgets/category_sidebar.dart';
import '../widgets/result_log.dart';
import '../panels/basic_panel.dart';
import '../panels/ttl_panel.dart';
import '../panels/lru_panel.dart';
import '../panels/json_panel.dart';
import '../panels/combo_panel.dart';
import '../panels/custom_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LogController _log = LogController();
  TestCategory _selectedCategory = TestCategories.basic;

  @override
  void initState() {
    super.initState();
    _log.info('HiveHook Demo initialized');
    _log.info('Select a test category from the sidebar');
  }

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  Widget _buildPanel() {
    return switch (_selectedCategory.id) {
      'basic' => BasicTestPanel(log: _log),
      'ttl' => TTLTestPanel(log: _log),
      'lru' => LRUTestPanel(log: _log),
      'json' => JsonTestPanel(log: _log),
      'combo' => ComboTestPanel(log: _log),
      'custom' => CustomTestPanel(log: _log),
      _ => BasicTestPanel(log: _log),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left sidebar
          CategorySidebar(
            selected: _selectedCategory,
            onSelect: (category) {
              setState(() => _selectedCategory = category);
              _log.info('Switched to ${category.name}', category: category.id);
            },
          ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top: Test panel
                Expanded(
                  flex: 3,
                  child: _buildPanel(),
                ),

                // Bottom: Result log
                SizedBox(
                  height: 200,
                  child: ResultLog(controller: _log),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
