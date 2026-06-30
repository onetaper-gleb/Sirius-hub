import 'package:flutter/foundation.dart';

class ButtonNotifier extends ChangeNotifier implements ValueListenable<bool> {
  bool _value = true;
  double _lastScrollOffset = 0;

  @override
  bool get value => _value;

  void updateOnScroll(double currentOffset) {
    final shouldShow = currentOffset <= 0 || currentOffset < _lastScrollOffset;
    if (shouldShow != _value) {
      _value = shouldShow;
      notifyListeners();
    }
    _lastScrollOffset = currentOffset;
  }
}
