int _uidCounter = 0;

/// Base class for all hooks, providing unique identification.
class BaseHook {
  final String uid;

  BaseHook() : uid = 'hook_${_uidCounter++}';

  @override
  String toString() => 'BaseHook(uid: $uid)';

  @override
  int get hashCode => uid.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseHook && runtimeType == other.runtimeType && uid == other.uid;
}
