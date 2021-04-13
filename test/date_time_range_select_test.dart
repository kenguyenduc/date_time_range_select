import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:date_time_range_select/date_time_range_select.dart';

void main() {
  const MethodChannel channel = MethodChannel('date_time_range_select');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });
}
