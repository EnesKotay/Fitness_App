import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class AssistantFabVisibility {
  const AssistantFabVisibility._();

  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);
  static int _hideRequests = 0;
  static bool _updateScheduled = false;

  static void hide() {
    _hideRequests += 1;
    _scheduleHiddenSync();
  }

  static void show() {
    if (_hideRequests > 0) {
      _hideRequests -= 1;
    }
    _scheduleHiddenSync();
  }

  static void _scheduleHiddenSync() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      final nextHidden = _hideRequests > 0;
      if (hidden.value != nextHidden) {
        hidden.value = nextHidden;
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
