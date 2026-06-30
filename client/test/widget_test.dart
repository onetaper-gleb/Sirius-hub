import 'package:client/module/widgets/button_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ButtonNotifier hides on downward scroll and shows on upward', () {
    final notifier = ButtonNotifier();
    final values = <bool>[notifier.value];

    notifier.addListener(() {
      values.add(notifier.value);
    });

    notifier.updateOnScroll(20);
    notifier.updateOnScroll(10);

    expect(values, <bool>[true, false, true]);
  });
}
