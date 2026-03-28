import 'package:flutter_test/flutter_test.dart';
import 'package:cgm_app/services/notification_plugin.dart';

void main() {
  test('notificationPlugin is a non-null singleton', () {
    final a = notificationPlugin;
    final b = notificationPlugin;
    expect(a, isNotNull);
    expect(identical(a, b), isTrue);
  });
}
