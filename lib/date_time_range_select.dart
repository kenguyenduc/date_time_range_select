
import 'dart:async';

import 'package:flutter/services.dart';

class DateTimeRangeSelect {
  static const MethodChannel _channel =
      const MethodChannel('date_time_range_select');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
