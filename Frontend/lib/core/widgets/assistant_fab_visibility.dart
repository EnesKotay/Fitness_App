import 'package:flutter/foundation.dart';

class AssistantFabVisibility {
  const AssistantFabVisibility._();

  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);
  static int _hideRequests = 0;

  static void hide() {
    _hideRequests += 1;
    hidden.value = true;
  }

  static void show() {
    if (_hideRequests > 0) {
      _hideRequests -= 1;
    }
    hidden.value = _hideRequests > 0;
  }
}
