/// Stub implementation for non-web platforms.
/// Debug object storage is only available on web.

/// Whether web debug is available on this platform.
bool get isWebDebugAvailable => false;

/// Maximum number of debug keys (no-op on non-web, but matches web API).
int maxDebugKeys = 1000;

/// Initialize web debug storage (no-op on non-web).
void initWebDebug() {}

/// Store a debug object (no-op on non-web).
void webDebugPut(String key, dynamic value) {}

/// Delete a debug object (no-op on non-web).
void webDebugDelete(String key) {}

/// Clear all debug objects (no-op on non-web).
void webDebugClear() {}

/// Get all debug keys (returns empty on non-web).
List<String> webDebugKeys() => [];
