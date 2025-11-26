import 'package:hivehook/core/enums.dart';

class HHLatch {
  final TriggerType triggerType;
  final bool isPost;
  final String? customEvent;
  final int priority;

  const HHLatch({
    required this.triggerType,
    this.isPost = true,
    this.customEvent,
    this.priority = 0,
  });

  factory HHLatch.custom({
    required String eventName,
    bool isPost = true,
    int priority = 0,
  }) {
    return HHLatch(
      triggerType: TriggerType.custom,
      isPost: isPost,
      customEvent: eventName,
      priority: priority,
    );
  }

  factory HHLatch.pre({
    required TriggerType triggerType,
    String? customEvent,
    int priority = 0,
  }) {
    return HHLatch(
      triggerType: triggerType,
      isPost: false,
      customEvent: customEvent,
      priority: priority,
    );
  }

}
