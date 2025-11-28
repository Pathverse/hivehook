import 'package:hivehook/core/config.dart';

/// Central file for all test configurations
/// All tests should reference configs from here instead of creating their own
/// Hook and control flow tests need dynamic hooks, so they create configs on-demand

void initializeAllTestConfigs() {
  // Config tests
  HHImmutableConfig(env: 'test_env', usesMeta: true);
  HHImmutableConfig(env: 'test_env_no_meta', usesMeta: false);

  // CRUD tests
  HHImmutableConfig(env: 'crud_put_get', usesMeta: true);
  HHImmutableConfig(env: 'crud_null', usesMeta: true);
  HHImmutableConfig(env: 'crud_delete', usesMeta: true);
  HHImmutableConfig(env: 'crud_pop', usesMeta: true);
  HHImmutableConfig(env: 'crud_clear', usesMeta: true);
  HHImmutableConfig(env: 'crud_update', usesMeta: true);
  HHImmutableConfig(env: 'crud_test', usesMeta: true);

  // Metadata tests
  HHImmutableConfig(env: 'meta_basic', usesMeta: true);
  HHImmutableConfig(env: 'meta_update', usesMeta: true);
  HHImmutableConfig(env: 'meta_pop', usesMeta: true);
  HHImmutableConfig(env: 'meta_independent', usesMeta: true);
  HHImmutableConfig(env: 'meta_delete', usesMeta: true);

  // Hook and control flow test placeholders - will be replaced with actual hooks
  HHImmutableConfig(env: 'hooks_pre', usesMeta: true);
  HHImmutableConfig(env: 'hooks_post', usesMeta: true);
  HHImmutableConfig(env: 'hooks_priority', usesMeta: true);
  HHImmutableConfig(env: 'hooks_context', usesMeta: true);
  HHImmutableConfig(env: 'hooks_both', usesMeta: true);
  HHImmutableConfig(env: 'hooks_types', usesMeta: true);
  HHImmutableConfig(env: 'hooks_meta', usesMeta: true);

  HHImmutableConfig(env: 'control_break', usesMeta: true);
  HHImmutableConfig(env: 'control_skip', usesMeta: true);
  HHImmutableConfig(env: 'control_continue', usesMeta: true);
  HHImmutableConfig(env: 'control_panic', usesMeta: true);
  HHImmutableConfig(env: 'control_delete', usesMeta: true);
  HHImmutableConfig(env: 'control_pop', usesMeta: true);
  HHImmutableConfig(env: 'control_nested', usesMeta: true);

  // ifNotCached tests
  HHImmutableConfig(env: 'if_not_cached_first', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_cached', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_keys', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_async', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_meta', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_complex', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_null', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_static', usesMeta: true);
  HHImmutableConfig(env: 'if_not_cached_error', usesMeta: true);
}
