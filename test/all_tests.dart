import 'dart:io';
import 'package:hivehook/core/base.dart';
import 'package:test/test.dart';
import 'test_configs.dart';
import 'config_test.dart' as config_test;
import 'crud_test.dart' as crud_test;
import 'metadata_test.dart' as metadata_test;
import 'hooks_test.dart' as hooks_test;
import 'control_flow_test.dart' as control_flow_test;

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // One temp directory and collection for ALL tests
    tempDir = await Directory.systemTemp.createTemp('hivehook_all_tests_');
    HHiveCore.HIVE_INIT_PATH = tempDir.path;
    HHiveCore.HIVE_BOX_COLLECTION_NAME = 'all_tests';

    // Initialize all configs once
    initializeAllTestConfigs();
    await HHiveCore.initialize();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        // Ignore deletion errors
      }
    }
  });

  config_test.main();
  crud_test.main();
  metadata_test.main();
  hooks_test.main();
  control_flow_test.main();
}
