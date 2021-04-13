import 'package:date_time_range_select/model/result_picked.dart';
import 'package:flutter/material.dart';
import 'package:date_time_range_select/date_time_range_select_plugin.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DateRangePickerExample(),
      // Scaffold(
      //   appBar: AppBar(
      //     title: const Text('Plugin example app'),
      //   ),
      //   body: Center(
      //     child: Text('test'),
      //   ),
      // ),
    );
  }
}

class DateRangePickerExample extends StatefulWidget {
  @override
  _DateRangePickerExampleState createState() => _DateRangePickerExampleState();
}

class _DateRangePickerExampleState extends State<DateRangePickerExample> {
  Color colorPrimary = Colors.green;
  DateTime initialFirstDate =
      DateTime.now().subtract(Duration(days: DateTime.now().day - 1));
  DateTime initialLastDate = DateTime.now();
  ResultPicked picked = ResultPicked();
  TagTime _tagTime = TagTime.none;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Date range picker plugin'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Từ ngày: $initialFirstDate \n Đến ngày: $initialLastDate \n TagTime: $_tagTime',
              style: TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 20),
            RaisedButton(
              child: Padding(
                padding: const EdgeInsets.only(
                    top: 10.0, bottom: 10.0, left: 30.0, right: 30.0),
                child: Text(
                  "Date Picker",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              onPressed: () async {
                picked = await showDateTimeSelect(
                  context: context,
                  initialFirstDate: initialFirstDate,
                  initialLastDate: initialLastDate,
                  tagTime: _tagTime,
                  firstDate: DateTime(2015),
                  lastDate: DateTime(2030),
                );
                initialFirstDate = picked.selectedFirstDate!;
                initialLastDate = picked.selectedLastDate!;
                _tagTime = picked.tagTime!;
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
