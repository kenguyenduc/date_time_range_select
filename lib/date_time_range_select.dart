library date_range_picker;

// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'widgets/custom_button.dart';
import 'widgets/tag_time_view.dart';
import 'model/result_picked.dart';

// const double _kDatePickerHeaderPortraitHeight = 72.0;
// const double _kDatePickerHeaderLandscapeWidth = 168.0;

const Duration _kMonthScrollDuration = Duration(milliseconds: 200);
const double _kDayPickerRowHeight = 42.0;
const int _kMaxDayPickerRowCount = 6; // A 31 day month that starts on Saturday.
// Two extra rows: one for the day-of-week header and one for the month header.
const double _kMaxDayPickerHeight =
    _kDayPickerRowHeight * (_kMaxDayPickerRowCount + 2);

// const double _kMonthPickerPortraitWidth = 330.0;
// const double _kMonthPickerLandscapeWidth = 344.0;

// const double _kDialogActionBarHeight = 52.0;
// const double _kDatePickerLandscapeHeight =
//     _kMaxDayPickerHeight + _kDialogActionBarHeight;

class _DayPickerGridDelegate extends SliverGridDelegate {
  const _DayPickerGridDelegate();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    const int columnCount = DateTime.daysPerWeek;
    final double tileWidth = constraints.crossAxisExtent / columnCount;
    final double tileHeight = math.min(_kDayPickerRowHeight,
        constraints.viewportMainAxisExtent / (_kMaxDayPickerRowCount + 1));
    return SliverGridRegularTileLayout(
      crossAxisCount: columnCount,
      mainAxisStride: tileHeight,
      crossAxisStride: tileWidth,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(_DayPickerGridDelegate oldDelegate) => false;
}

const _DayPickerGridDelegate _kDayPickerGridDelegate = _DayPickerGridDelegate();

/// Displays the days of a given month and allows choosing a day.
///
/// The days are arranged in a rectangular grid with one column for each day of
/// the week.
///
/// The day picker widget is rarely used directly. Instead, consider using
/// [showDatePicker], which creates a date picker dialog.
///
/// See also:
///
///  * [showDatePicker].
///  * <https://material.google.com/components/pickers.html#pickers-date-pickers>
// ignore: must_be_immutable
class DayPicker extends StatelessWidget {
  /// Creates a day picker.
  ///
  /// Rarely used directly. Instead, typically used as part of a [MonthPicker].
  DayPicker({
    Key? key,
    required this.selectedFirstDate,
    this.selectedLastDate,
    required this.currentDate,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    required this.displayedMonth,
    required this.refreshTagTime,
    this.selectableDayPredicate,
  })  : assert(selectedFirstDate != null),
        assert(currentDate != null),
        assert(onChanged != null),
        assert(displayedMonth != null),
        assert(!firstDate.isAfter(lastDate)),
        assert(!selectedFirstDate.isBefore(firstDate) &&
            (selectedLastDate == null || !selectedLastDate.isAfter(lastDate))),
        assert(selectedLastDate == null ||
            !selectedLastDate.isBefore(selectedFirstDate)),
        super(key: key);

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final DateTime selectedFirstDate;
  final DateTime? selectedLastDate;

  /// The current date at the time the picker is displayed.
  final DateTime currentDate;

  /// Called when the user picks a day.
  final ValueChanged<List<DateTime?>?> onChanged;

  /// The earliest date the user is permitted to pick.
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  final DateTime lastDate;

  /// The month whose days are displayed by this picker.
  final DateTime displayedMonth;

  /// Optional user supplied predicate function to customize selectable days.
  final SelectableDayPredicate? selectableDayPredicate;

  /// refresh tag time none when selected date
  VoidCallback refreshTagTime;

  /// Builds widgets showing abbreviated days of week. The first widget in the
  /// returned list corresponds to the first day of week for the current locale.
  ///
  /// Examples:
  ///
  /// ```
  /// ┌ Sunday is the first day of week in the US (en_US)
  /// |
  /// S M T W T F S  <-- the returned list contains these widgets
  /// _ _ _ _ _ 1 2
  /// 3 4 5 6 7 8 9
  ///
  /// ┌ But it's Monday in the UK (en_GB)
  /// |
  /// M T W T F S S  <-- the returned list contains these widgets
  /// _ _ _ _ 1 2 3
  /// 4 5 6 7 8 9 10
  /// ```
  List<Widget> _getDayHeaders(
      TextStyle headerStyle, MaterialLocalizations localizations) {
    final List<Widget> result = <Widget>[];
    for (int i = localizations.firstDayOfWeekIndex; true; i = (i + 1) % 7) {
      final String weekday = localizations.narrowWeekdays[i];
      result.add(ExcludeSemantics(
        child: Center(child: Text(weekday, style: headerStyle)),
      ));
      if (i == (localizations.firstDayOfWeekIndex - 1) % 7) break;
    }
    return result;
  }

  // Do not use this directly - call getDaysInMonth instead.
  static const List<int> _daysInMonth = <int>[
    31,
    -1,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
  ];

  /// Returns the number of days in a month, according to the proleptic
  /// Gregorian calendar.
  ///
  /// This applies the leap year logic introduced by the Gregorian reforms of
  /// 1582. It will not give valid results for dates prior to that time.
  static int getDaysInMonth(int year, int month) {
    if (month == DateTime.february) {
      final bool isLeapYear =
          (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);
      if (isLeapYear) return 29;
      return 28;
    }
    return _daysInMonth[month - 1];
  }

  /// Computes the offset from the first day of week that the first day of the
  /// [month] falls on.
  ///
  /// For example, September 1, 2017 falls on a Friday, which in the calendar
  /// localized for United States English appears as:
  ///
  /// ```
  /// S M T W T F S
  /// _ _ _ _ _ 1 2
  /// ```
  ///
  /// The offset for the first day of the months is the number of leading blanks
  /// in the calendar, i.e. 5.
  ///
  /// The same date localized for the Russian calendar has a different offset,
  /// because the first day of week is Monday rather than Sunday:
  ///
  /// ```
  /// M T W T F S S
  /// _ _ _ _ 1 2 3
  /// ```
  ///
  /// So the offset is 4, rather than 5.
  ///
  /// This code consolidates the following:
  ///
  /// - [DateTime.weekday] provides a 1-based index into days of week, with 1
  ///   falling on Monday.
  /// - [MaterialLocalizations.firstDayOfWeekIndex] provides a 0-based index
  ///   into the [MaterialLocalizations.narrowWeekdays] list.
  /// - [MaterialLocalizations.narrowWeekdays] list provides localized names of
  ///   days of week, always starting with Sunday and ending with Saturday.
  int _computeFirstDayOffset(
      int year, int month, MaterialLocalizations localizations) {
    // 0-based day of week, with 0 representing Monday.
    final int weekdayFromMonday = DateTime(year, month).weekday - 1;
    // 0-based day of week, with 0 representing Sunday.
    final int firstDayOfWeekFromSunday = localizations.firstDayOfWeekIndex;
    // firstDayOfWeekFromSunday recomputed to be Monday-based
    final int firstDayOfWeekFromMonday = (firstDayOfWeekFromSunday - 1) % 7;
    // Number of days between the first day of week appearing on the calendar,
    // and the day corresponding to the 1-st of the month.
    return (weekdayFromMonday - firstDayOfWeekFromMonday) % 7;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    final int year = displayedMonth.year;
    final int month = displayedMonth.month;
    final int daysInMonth = getDaysInMonth(year, month);
    final int firstDayOffset =
        _computeFirstDayOffset(year, month, localizations);
    final List<Widget> labels = <Widget>[];
    TextStyle _textStyleHeader = TextStyle(
        color: Color(0xFF2C333A), fontWeight: FontWeight.bold, fontSize: 15);
    labels.addAll(_getDayHeaders(_textStyleHeader, localizations));
    for (int i = 0; true; i += 1) {
      // 1-based day of month, e.g. 1-31 for January, and 1-29 for February on
      // a leap year.
      final int day = i - firstDayOffset + 1;
      if (day > daysInMonth) break;
      if (day < 1) {
        labels.add(Container());
      } else {
        final DateTime dayToBuild = DateTime(year, month, day);
        final bool disabled = dayToBuild.isAfter(lastDate) ||
            dayToBuild.isBefore(firstDate) ||
            (selectableDayPredicate != null &&
                !selectableDayPredicate!(dayToBuild));
        BoxDecoration? decoration;
        TextStyle? itemStyle = themeData.textTheme.bodyText2;
        final bool isSelectedFirstDay = selectedFirstDate.year == year &&
            selectedFirstDate.month == month &&
            selectedFirstDate.day == day;
        final bool? isSelectedLastDay = selectedLastDate != null
            ? (selectedLastDate!.year == year &&
                selectedLastDate!.month == month &&
                selectedLastDate!.day == day)
            : null;
        final bool? isInRange = selectedLastDate != null
            ? (dayToBuild.isBefore(selectedLastDate!) &&
                dayToBuild.isAfter(selectedFirstDate))
            : null;
        if (isSelectedFirstDay &&
            (isSelectedLastDay == null || isSelectedLastDay)) {
          itemStyle = themeData.accentTextTheme.bodyText1;
          decoration = BoxDecoration(
              color: Color(0xFF28A745),
              borderRadius: BorderRadius.circular(8.0));
        } else if (isSelectedFirstDay) {
          // The selected day gets a circle background highlight, and a contrasting text color.
          itemStyle = themeData.accentTextTheme.bodyText1;
          decoration = BoxDecoration(
            color: Color(0xFF28A745),
            borderRadius: BorderRadius.circular(8.0),
            // borderRadius: BorderRadius.only(
            //   topLeft:  Radius.circular(50.0),
            //   bottomLeft:  Radius.circular(50.0),
            // ),
          );
        } else if (isSelectedLastDay != null && isSelectedLastDay) {
          itemStyle = themeData.accentTextTheme.bodyText1;
          decoration = BoxDecoration(
            color: Color(0xFF28A745),
            borderRadius: BorderRadius.circular(8.0),
            // borderRadius: BorderRadius.only(
            //   topRight:  Radius.circular(50.0),
            //   bottomRight:  Radius.circular(50.0),
            // ),
          );
        } else if (isInRange != null && isInRange) {
          decoration = BoxDecoration(
              color: Color(0xFF28A745).withOpacity(0.1),
              shape: BoxShape.rectangle);
        } else if (disabled) {
          if (themeData.textTheme.bodyText2 != null) {
            itemStyle = themeData.textTheme.bodyText2!
                .copyWith(color: themeData.disabledColor);
          }
        } else if (currentDate.year == year &&
            currentDate.month == month &&
            currentDate.day == day) {
          // The current day gets a different text color.
          // itemStyle =
          //     themeData.textTheme.bodyText1.copyWith(color: themeData.accentColor);
          itemStyle =
              themeData.textTheme.bodyText2?.apply(color: Color(0xFF28A745));
          decoration = BoxDecoration(
            border: Border.all(color: Color(0xFF28A745), width: 1),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8.0),
          );
        }

        Widget dayWidget = Container(
          decoration: decoration,
          child: Center(
            child: Semantics(
              // We want the day of month to be spoken first irrespective of the
              // locale-specific preferences or TextDirection. This is because
              // an accessibility user is more likely to be interested in the
              // day of month before the rest of the date, as they are looking
              // for the day of month. To do that we prepend day of month to the
              // formatted full date.
              label:
                  '${localizations.formatDecimal(day)}, ${localizations.formatFullDate(dayToBuild)}',
              selected: isSelectedFirstDay ||
                  isSelectedLastDay != null && isSelectedLastDay,
              child: ExcludeSemantics(
                child: Text(localizations.formatDecimal(day), style: itemStyle),
              ),
            ),
          ),
        );

        if (!disabled) {
          dayWidget = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              DateTime? first, last;
              refreshTagTime();
              if (selectedLastDate != null) {
                first = dayToBuild;
                last = null;
              } else {
                if (dayToBuild.compareTo(selectedFirstDate) <= 0) {
                  first = dayToBuild;
                  last = selectedFirstDate;
                } else {
                  first = selectedFirstDate;
                  last = dayToBuild;
                }
              }
              onChanged([first, last]);
            },
            child: dayWidget,
          );
        }

        labels.add(dayWidget);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: <Widget>[
          //  Container(
          //   height: _kDayPickerRowHeight,
          //   child:  Center(
          //     child:  ExcludeSemantics(
          //       child:  Text(
          //         localizations.formatMonthYear(displayedMonth),
          //         style: themeData.textTheme.subtitle1,
          //       ),
          //     ),
          //   ),
          // ),
          Flexible(
            child: GridView.custom(
              gridDelegate: _kDayPickerGridDelegate,
              padding: EdgeInsets.all(10),
              childrenDelegate:
                  SliverChildListDelegate(labels, addRepaintBoundaries: false),
            ),
          ),
        ],
      ),
    );
  }
}

/// A scrollable list of months to allow picking a month.
///
/// Shows the days of each month in a rectangular grid with one column for each
/// day of the week.
///
/// The month picker widget is rarely used directly. Instead, consider using
/// [showDatePicker], which creates a date picker dialog.
///
/// See also:
///
///  * [showDatePicker]
///  * <https://material.google.com/components/pickers.html#pickers-date-pickers>
// ignore: must_be_immutable
class MonthPicker extends StatefulWidget {
  /// Creates a month picker.
  ///
  /// Rarely used directly. Instead, typically used as part of the dialog shown
  /// by [showDatePicker].
  MonthPicker({
    Key? key,
    required this.selectedFirstDate,
    required this.selectedLastDate,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    required this.refreshTagTime,
    this.selectableDayPredicate,
  })  : assert(selectedFirstDate != null),
        assert(onChanged != null),
        assert(!firstDate.isAfter(lastDate)),
        assert(!selectedFirstDate.isBefore(firstDate) &&
            (selectedLastDate == null || !selectedLastDate.isAfter(lastDate))),
        assert(selectedLastDate == null ||
            !selectedLastDate.isBefore(selectedFirstDate)),
        super(key: key);

  /// The currently selected date.
  ///
  /// This date is highlighted in the picker.
  final DateTime selectedFirstDate;
  final DateTime selectedLastDate;

  /// Called when the user picks a month.
  final ValueChanged<List<DateTime?>?> onChanged;

  /// The earliest date the user is permitted to pick.
  final DateTime firstDate;

  /// The latest date the user is permitted to pick.
  final DateTime lastDate;

  /// Optional user supplied predicate function to customize selectable days.
  final SelectableDayPredicate? selectableDayPredicate;

  /// refresh Tag Time None when selected date
  VoidCallback refreshTagTime;

  @override
  _MonthPickerState createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker>
    with SingleTickerProviderStateMixin {
  late DateTime _todayDate;
  late DateTime _currentDisplayedMonthDate;
  Timer? _timer;
  late PageController _dayPickerController;
  late AnimationController _chevronOpacityController;
  late Animation<double> _chevronOpacityAnimation;
  bool _isEnabled = true;

  String _dropdownValueMonth = '1';
  final List<String> _listMonth = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12'
  ];

  String _dropdownValueYear = DateTime.now().year.toString();
  List<String> _listYear = <String>[];

  void _loadListYear() {
    int _firstYear = widget.firstDate.year;
    int _lastYear = widget.lastDate.year;
    for (int i = _firstYear; i <= _lastYear; i++) {
      _listYear.add(i.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadListYear();
    // Initially display the pre-selected date.
    int monthPage;
    if (widget.selectedLastDate == null) {
      monthPage = _monthDelta(widget.firstDate, widget.selectedFirstDate);
    } else {
      monthPage = _monthDelta(widget.firstDate, widget.selectedLastDate);
    }
    _dayPickerController = PageController(initialPage: monthPage);
    _handleMonthPageChanged(monthPage);
    _updateCurrentDate();

    // Setup the fade animation for chevrons
    _chevronOpacityController = AnimationController(
        duration: const Duration(milliseconds: 250), vsync: this);
    _chevronOpacityAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _chevronOpacityController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(MonthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLastDate == null) {
      final int monthPage =
          _monthDelta(widget.firstDate, widget.selectedFirstDate);
      _dayPickerController = PageController(initialPage: monthPage);
      _handleMonthPageChanged(monthPage);
    } else if (oldWidget.selectedLastDate == null ||
        widget.selectedLastDate != oldWidget.selectedLastDate) {
      final int monthPage =
          _monthDelta(widget.firstDate, widget.selectedLastDate);
      _dayPickerController = PageController(initialPage: monthPage);
      _handleMonthPageChanged(monthPage);
    }
  }

  // MaterialLocalizations localizations;
  // TextDirection textDirection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // localizations = MaterialLocalizations.of(context);
    // textDirection = Directionality.of(context);
  }

  /// Cập nhật ngày hiện tại
  void _updateCurrentDate() {
    _todayDate = DateTime.now();
    final DateTime tomorrow =
        DateTime(_todayDate.year, _todayDate.month, _todayDate.day + 1);
    Duration timeUntilTomorrow = tomorrow.difference(_todayDate);
    timeUntilTomorrow +=
        const Duration(seconds: 1); // so we don't miss it by rounding
    _timer?.cancel();
    _timer = Timer(timeUntilTomorrow, () {
      setState(() {
        _updateCurrentDate();
      });
    });
  }

  ///Tính số tháng từ ngày bắt đầu đến ngày kết thúc
  static int _monthDelta(DateTime startDate, DateTime endDate) {
    return (endDate.year - startDate.year) * 12 +
        endDate.month -
        startDate.month;
  }

  /// Add months to a month truncated date.
  DateTime _addMonthsToMonthDate(DateTime monthDate, int monthsToAdd) {
    return DateTime(
        monthDate.year + monthsToAdd ~/ 12, monthDate.month + monthsToAdd % 12);
  }

  /// UI build item page view
  Widget _buildItems(BuildContext context, int index) {
    final DateTime month = _addMonthsToMonthDate(widget.firstDate, index);
    return DayPicker(
      key: ValueKey<DateTime>(month),
      selectedFirstDate: widget.selectedFirstDate,
      selectedLastDate: widget.selectedLastDate,
      currentDate: _todayDate,
      onChanged: widget.onChanged,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      displayedMonth: month,
      selectableDayPredicate: widget.selectableDayPredicate,
      refreshTagTime: widget.refreshTagTime,
    );
  }

  ///Load page view next month
  void _handleNextMonth() {
    if (!_isDisplayingLastMonth) {
      // SemanticsService.announce(
      //     localizations.formatMonthYear(_nextMonthDate), textDirection);
      _dayPickerController.nextPage(
          duration: _kMonthScrollDuration, curve: Curves.ease);
    }
  }

  ///Load page view previous month
  void _handlePreviousMonth() {
    if (!_isDisplayingFirstMonth) {
      // SemanticsService.announce(
      // localizations.formatMonthYear(_previousMonthDate), textDirection);
      _dayPickerController.previousPage(
          duration: _kMonthScrollDuration, curve: Curves.ease);
    }
  }

  /// True if the earliest allowable month is displayed.
  bool get _isDisplayingFirstMonth {
    return !_currentDisplayedMonthDate
        .isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));
  }

  /// True if the latest allowable month is displayed.
  bool get _isDisplayingLastMonth {
    return !_currentDisplayedMonthDate
        .isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));
  }

  late DateTime _previousMonthDate;
  late DateTime _nextMonthDate;

  /// Xử lý cập nhật DateTimne theo index pageView
  void _handleMonthPageChanged(int monthPage) {
    setState(() {
      _previousMonthDate =
          _addMonthsToMonthDate(widget.firstDate, monthPage - 1);
      _currentDisplayedMonthDate =
          _addMonthsToMonthDate(widget.firstDate, monthPage);
      _nextMonthDate = _addMonthsToMonthDate(widget.firstDate, monthPage + 1);

      _dropdownValueMonth = _currentDisplayedMonthDate.month.toString();
      _dropdownValueYear = _currentDisplayedMonthDate.year.toString();
    });
  }

  ///UI build IconButton previous month + DropdownSelectMonth + DropdownSelectYear + next month
  Widget _buildHeaderCalendar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildHeaderCalendarIcon(
          sortKey: _MonthPickerSortKey.previousMonth,
          iconData: Icons.arrow_back_ios_outlined,
          onTap: _isDisplayingFirstMonth && _isEnabled
              ? null
              : _handlePreviousMonth,
        ),
        Row(
          children: [
            _buildDropdownSelectMonth(),
            const SizedBox(width: 10),
            _buildDropdownSelectYear(),
          ],
        ),
        _buildHeaderCalendarIcon(
            sortKey: _MonthPickerSortKey.nextMonth,
            iconData: Icons.arrow_forward_ios_outlined,
            onTap:
                _isDisplayingLastMonth && _isEnabled ? null : _handleNextMonth),
      ],
    );
  }

  Widget _buildHeaderCalendarIcon(
      {required SemanticsSortKey sortKey,
      required IconData iconData,
      GestureTapCallback? onTap}) {
    return Semantics(
      sortKey: sortKey,
      child: FadeTransition(
        opacity: _chevronOpacityAnimation,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.white,
                border: Border.all(color: Color(0xFFE9EDF2))),
            child: Icon(
              iconData,
              color: Color(0xFF858F9B),
              size: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSelectMonth() {
    final TextStyle _textStyle =
        TextStyle(color: Color(0xFF2C333A), fontFamily: 'Lato', fontSize: 15);
    return Container(
      height: 37,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
          border: Border.all(color: Color(0xFFE9EDF2))),
      child: DropdownButton<String>(
        value: _dropdownValueMonth,
        iconSize: 24,
        elevation: 16,
        dropdownColor: Colors.white,
        style: _textStyle,
        underline: SizedBox.shrink(),
        onChanged: _handleDropdownMonthChanged,
        items: _listMonth.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text('Tháng ' + value, style: _textStyle),
          );
        }).toList(),
      ),
    );
  }

  void _handleDropdownMonthChanged(String? newValue) {
    if (newValue != null) {
      _dropdownValueMonth = newValue;
    }
    _dayPickerController.jumpToPage(
        (int.parse(_dropdownValueYear) - widget.firstDate.year) * 12 +
            int.parse(_dropdownValueMonth) -
            widget.firstDate.month);
    setState(() {});
  }

  Widget _buildDropdownSelectYear() {
    final TextStyle _textStyle =
        TextStyle(color: Color(0xFF2C333A), fontFamily: 'Lato', fontSize: 15);
    return Container(
      height: 37,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
          border: Border.all(color: Color(0xFFE9EDF2))),
      child: DropdownButton<String>(
        value: _dropdownValueYear,
        iconSize: 24,
        elevation: 16,
        dropdownColor: Colors.white,
        style: _textStyle,
        underline: SizedBox(),
        onChanged: _handleDropdownYearChanged,
        items: _listYear.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: _textStyle),
          );
        }).toList(),
      ),
    );
  }

  void _handleDropdownYearChanged(String? newValue) {
    if (newValue != null) {
      _dropdownValueYear = newValue;
    }
    _dayPickerController.jumpToPage(
        (int.parse(_dropdownValueYear) - widget.firstDate.year) * 12 +
            int.parse(_dropdownValueMonth) -
            widget.firstDate.month);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          _buildHeaderCalendar(),
          SizedBox(
            height: _kMaxDayPickerHeight - 40,
            child: Semantics(
              sortKey: _MonthPickerSortKey.calendar,
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (_) {
                  _chevronOpacityController.forward();
                  return false;
                },
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: (_) {
                    _chevronOpacityController.reverse();
                    return false;
                  },
                  child: PageView.builder(
                    key: ValueKey<DateTime?>(widget.selectedFirstDate == null
                        ? null
                        : widget.selectedLastDate),
                    controller: _dayPickerController,
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        _monthDelta(widget.firstDate, widget.lastDate) + 1,
                    itemBuilder: _buildItems,
                    onPageChanged: _handleMonthPageChanged,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    // _dayPickerController?.dispose();
    super.dispose();
  }
}

// Defines semantic traversal order of the top-level widgets inside the month
// picker.
class _MonthPickerSortKey extends OrdinalSortKey {
  static const _MonthPickerSortKey previousMonth = _MonthPickerSortKey(1.0);
  static const _MonthPickerSortKey nextMonth = _MonthPickerSortKey(2.0);
  static const _MonthPickerSortKey calendar = _MonthPickerSortKey(3.0);

  const _MonthPickerSortKey(double order) : super(order);
}

/// Signature for predicating dates for enabled date selections.
///
/// See [showDatePicker].
typedef bool SelectableDayPredicate(DateTime day);

/// Shows a dialog containing a material design date picker.
///
/// The returned [Future] resolves to the date selected by the user when the
/// user closes the dialog. If the user cancels the dialog, null is returned.
///
/// An optional [selectableDayPredicate] function can be passed in to customize
/// the days to enable for selection. If provided, only the days that
/// [selectableDayPredicate] returned true for will be selectable.
///
/// An optional [initialDatePickerMode] argument can be used to display the
/// date picker initially in the year or month+day picker mode. It defaults
/// to month+day, and must not be null.
///
/// An optional [locale] argument can be used to set the locale for the date
/// picker. It defaults to the ambient locale provided by [Localizations].
///
/// An optional [textDirection] argument can be used to set the text direction
/// (RTL or LTR) for the date picker. It defaults to the ambient text direction
/// provided by [Directionality]. If both [locale] and [textDirection] are not
/// null, [textDirection] overrides the direction chosen for the [locale].
///
/// The `context` argument is passed to [showDialog], the documentation for
/// which discusses how it is used.
///
/// See also:
///
///  * [showTimePicker]
///  * <https://material.google.com/components/pickers.html#pickers-date-pickers>

Future<ResultPicked> showDateTimeSelect({
  required BuildContext context,
  required DateTime initialFirstDate,
  required DateTime initialLastDate,
  required TagTime tagTime,
  required DateTime firstDate,
  required DateTime lastDate,
  SelectableDayPredicate? selectableDayPredicate,
  Locale? locale,
  TextDirection? textDirection,
}) async {
  assert(!initialFirstDate.isBefore(firstDate),
      'initialDate must be on or after firstDate');
  assert(!initialLastDate.isAfter(lastDate),
      'initialDate must be on or before lastDate');
  assert(!initialFirstDate.isAfter(initialLastDate),
      'initialFirstDate must be on or before initialLastDate');
  assert(
      !firstDate.isAfter(lastDate), 'lastDate must be on or after firstDate');
  assert(
      selectableDayPredicate == null ||
          selectableDayPredicate(initialFirstDate) ||
          selectableDayPredicate(initialLastDate),
      'Provided initialDate must satisfy provided selectableDayPredicate');

  DatePickerMode initialDatePickerMode = DatePickerMode.day;

  return await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return _DatePickerBottomSheet(
          initialFirstDate: initialFirstDate,
          initialLastDate: initialLastDate,
          tagTime: tagTime,
          firstDate: firstDate,
          lastDate: lastDate,
          selectableDayPredicate: selectableDayPredicate,
          initialDatePickerMode: initialDatePickerMode,
        );
      });
}

class _DatePickerBottomSheet extends StatefulWidget {
  final DateTime initialFirstDate;
  final DateTime initialLastDate;
  final TagTime? tagTime;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final SelectableDayPredicate? selectableDayPredicate;
  final DatePickerMode? initialDatePickerMode;

  const _DatePickerBottomSheet(
      {Key? key,
      required this.initialFirstDate,
      required this.initialLastDate,
      required this.tagTime,
      this.firstDate,
      this.lastDate,
      this.selectableDayPredicate,
      this.initialDatePickerMode})
      : super(key: key);

  @override
  _DatePickerBottomSheetState createState() => _DatePickerBottomSheetState();
}

class _DatePickerBottomSheetState extends State<_DatePickerBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _announcedInitialDate = false;

  MaterialLocalizations? localizations;
  TextDirection? textDirection;

  late DateTime _selectedFirstDate;
  late DateTime _selectedLastDate;

  late bool _isSelectedTagToday;
  late bool _isSelectedTagCurrentMonth;
  late bool _isSelectedTagCurrentYear;
  late bool _isSelectedTagThirtyDaysPassed;

  late bool _isSelectedTagYesterday;
  late bool _isSelectedTagSevenDaysPassed;
  late bool _isSelectedTagNinetyDaysPassed;

  late bool _isSelectedTagLastMonth;
  late bool _isSelectedTagLastYear;

  double _heightBottomSheet = 724;

  // TabController _tabController;

  final DateTime _dateTimeNow = DateTime.now();

  /// Ngày hôm nay 0h0'0''
  late DateTime _today;

  ResultPicked _resultPicked = ResultPicked();

  late String _dropdownValueFromMonth;
  late String _dropdownValueToMonth;

  late String _dropdownValueFromYear;
  late String _dropdownValueToYear;

  List<String> _listYearRangeSelect = <String>[];
  List<String> _listMonthRangeSelect = <String>[];

  /// Xử lý cập nhật list item dropdown chọn từ tháng đến tháng
  void _loadListYearRangeSelect() {
    _dropdownValueFromYear = _dateTimeNow.year.toString();
    _dropdownValueToYear = _dateTimeNow.year.toString();
    int _firstYear = widget.firstDate!.year;
    int _currentYear = _dateTimeNow.year;
    for (int i = _firstYear; i <= _currentYear; i++) {
      _listYearRangeSelect.add(i.toString());
    }
  }

  /// Xử lý cập nhật list item dropdown chọn từ năm đến năm
  void _loadListMonthRangeSelect() {
    _dropdownValueFromMonth = '${_dateTimeNow.month}/${_dateTimeNow.year}';
    _dropdownValueToMonth = '${_dateTimeNow.month}/${_dateTimeNow.year}';
    int _firstYear = widget.firstDate!.year;
    int _currentYear = _dateTimeNow.year;
    //Cập nhật tháng những năm trước
    for (int i = _firstYear; i < _currentYear; i++) {
      for (int j = 1; j <= 12; j++) _listMonthRangeSelect.add('$j/$i');
    }
    //Thêm tháng đến tháng hiện tại
    for (int i = 1; i <= _dateTimeNow.month; i++) {
      _listMonthRangeSelect.add('$i/${_dateTimeNow.year}');
    }
  }

  @override
  void initState() {
    super.initState();
    _today = DateTime(_dateTimeNow.year, _dateTimeNow.month, _dateTimeNow.day);
    // _tabController = TabController(length: 4, vsync: this);
    // _tabController.addListener(_listenerTabController);
    _loadListMonthRangeSelect();
    _loadListYearRangeSelect();
    _loadStateTagTime();
  }

  // void _listenerTabController() {
  //   switch (_tabController.index) {
  //     case 0:
  //       _heightBottomSheet = 724;
  //       setState(() {});
  //       break;
  //     case 1:
  //       _heightBottomSheet = 747;
  //       setState(() {});
  //       break;
  //     case 2:
  //       _heightBottomSheet = 776;
  //       setState(() {});
  //       break;
  //     case 3:
  //       _heightBottomSheet = 724;
  //       setState(() {});
  //       break;
  //     default:
  //       break;
  //   }
  // }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = MaterialLocalizations.of(context);
    textDirection = Directionality.of(context);
    // if (!_announcedInitialDate) {
    //   _announcedInitialDate = true;
    //   SemanticsService.announce(
    //     localizations.formatFullDate(_selectedFirstDate),
    //     textDirection,
    //   );
    //   if (_selectedLastDate != null) {
    //     SemanticsService.announce(
    //       localizations.formatFullDate(_selectedLastDate),
    //       textDirection,
    //     );
    //   }
    // }
  }

  void _vibrate() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        HapticFeedback.vibrate();
        break;
      case TargetPlatform.iOS:
        break;
      default:
        break;
    }
  }

  /// Xử lý load trạng thái ban đầu của Tag time đã được chọn trước đó
  void _loadStateTagTime() {
    _selectedFirstDate = widget.initialFirstDate;
    _selectedLastDate = widget.initialLastDate;
    _resultPicked.tagTime = widget.tagTime ?? TagTime.none;

    _isSelectedTagToday = widget.tagTime == TagTime.today;
    _isSelectedTagCurrentMonth = widget.tagTime == TagTime.currentMonth;
    _isSelectedTagCurrentYear = widget.tagTime == TagTime.currentYear;
    _isSelectedTagThirtyDaysPassed = widget.tagTime == TagTime.thirtyDaysPassed;
    _isSelectedTagYesterday = widget.tagTime == TagTime.yesterday;
    _isSelectedTagSevenDaysPassed = widget.tagTime == TagTime.sevenDaysPassed;
    _isSelectedTagNinetyDaysPassed = widget.tagTime == TagTime.ninetyDaysPassed;
    _isSelectedTagLastMonth = widget.tagTime == TagTime.lastMonth;
    _isSelectedTagLastYear = widget.tagTime == TagTime.lastYear;
  }

  ///Lấy giá trị ngày đã chọn
  void _handleDayChanged(List<DateTime?>? changes) {
    assert(changes != null && changes.length == 2);
    _vibrate();
    _selectedFirstDate = changes![0]!;
    _selectedLastDate = changes[1]!;
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  /// Xử lý trả kết quả Ngày bắt đầu + Ngày kết thúc + Enum tag time
  void _handleOk() {
    if (_selectedFirstDate != null) {
      if (_selectedLastDate != null) {
        _resultPicked.selectedFirstDate = _selectedFirstDate;
        _resultPicked.selectedLastDate = _selectedLastDate;
      } else if (_selectedFirstDate ==
          DateTime(_dateTimeNow.year, _dateTimeNow.month, _dateTimeNow.day)) {
        _resultPicked.selectedFirstDate = _selectedFirstDate;
        _resultPicked.selectedLastDate = _dateTimeNow;
        _resultPicked.tagTime = TagTime.today;
        _isSelectedTagToday = true;
      } else {
        _resultPicked.selectedFirstDate = _selectedFirstDate;
        _resultPicked.selectedLastDate = DateTime(_selectedFirstDate.year,
            _selectedFirstDate.month, _selectedFirstDate.day, 23, 59, 59);
      }
    }
    Navigator.pop(context, _resultPicked);
  }

  Widget _buildPicker() {
    return MonthPicker(
      selectedFirstDate: _selectedFirstDate,
      selectedLastDate: _selectedLastDate,
      onChanged: _handleDayChanged,
      firstDate: widget.firstDate!,
      lastDate: widget.lastDate!,
      selectableDayPredicate: widget.selectableDayPredicate,
      refreshTagTime: _refreshTagTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    // final double _deviceHeight = MediaQuery.of(context).size.height;
    final TextStyle _textStyleTitleTab = TextStyle(
      fontFamily: 'Lato',
      fontSize: 15,
      letterSpacing: 0.23,
    );
    return SizedBox(
      height: _heightBottomSheet,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBottomSheet(context),
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TabBar(
                        isScrollable: true,
                        // controller: _tabController,
                        labelPadding: EdgeInsets.only(right: 20, left: 20),
                        labelColor: Color(0xFF28A745),
                        unselectedLabelColor: Color(0xFF929DAA),
                        indicatorColor: Color(0xFF28A745),
                        labelStyle: _textStyleTitleTab,
                        unselectedLabelStyle: _textStyleTitleTab,
                        tabs: [
                          Tab(text: 'Phổ biến'),
                          Tab(text: 'Ngày'),
                          Tab(text: 'Tháng'),
                          Tab(text: 'Năm'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          // controller: _tabController,
                          children: <Widget>[
                            _buildTabCommon(),
                            _buildTabDate(),
                            _buildTabMonth(),
                            _buildTabYear()
                          ],
                        ),
                      )
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// UI title Bottom sheet
  Widget _buildTitleBottomSheet(BuildContext context) {
    final TextStyle _textStyle = TextStyle(
        fontSize: 21, color: Color(0xFF2C333A), fontWeight: FontWeight.w500);
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      // width: double.infinity,
      height: 42,
      child: Stack(
        children: [
          Center(
            child: Text(
              'Chọn thời gian',
              style: _textStyle,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 24,
                  color: Color(0xFF2C333A),
                ),
                onPressed: () => Navigator.pop(context)),
          ),
        ],
      ),
    );
  }

  /// Xử lý chọn tag Hôm nay
  void _handleSelectedTagToday() {
    _selectedFirstDate =
        DateTime(_dateTimeNow.year, _dateTimeNow.month, _dateTimeNow.day);
    _selectedLastDate = _dateTimeNow;
    _resultPicked.tagTime = TagTime.today;

    _isSelectedTagToday = true;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  ///Xử lý chọn tag ngày hôm qua
  void _handleSelectedTagYesterday() {
    DateTime _yesterday = _today.subtract(Duration(days: 1));
    _selectedFirstDate =
        DateTime(_yesterday.year, _yesterday.month, _yesterday.day);
    _selectedLastDate =
        DateTime(_yesterday.year, _yesterday.month, _yesterday.day, 23, 59, 59);
    _resultPicked.tagTime = TagTime.yesterday;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = true;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý chọn tag Tháng này
  void _handleSelectedTagCurrentMonth() {
    _selectedFirstDate = DateTime(_dateTimeNow.year, _dateTimeNow.month);
    _selectedLastDate = _dateTimeNow;
    _resultPicked.tagTime = TagTime.currentMonth;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = true;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý chọn tag Năm này
  void _handleSelectedTagCurrentYear() {
    _selectedFirstDate = DateTime(_dateTimeNow.year);
    _selectedLastDate = _dateTimeNow;
    _resultPicked.tagTime = TagTime.currentYear;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = true;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý chọn tag 7 ngày trước
  void _handleSelectedTagSevenDaysPassed() {
    _selectedFirstDate = _today.subtract(Duration(days: 6));
    _selectedLastDate = _dateTimeNow;
    _resultPicked.tagTime = TagTime.sevenDaysPassed;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = true;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý chọn tag 30 ngày trước
  void _handleSelectedTagThirtyDaysPassed() {
    _selectedFirstDate = _today.subtract(Duration(days: 29));
    _selectedLastDate = _dateTimeNow;
    _resultPicked.tagTime = TagTime.thirtyDaysPassed;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = true;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý chọn tag 90 ngày trước
  void _handleSelectedTagNinetyDaysPassed() {
    _selectedFirstDate = _today.subtract(Duration(days: 89));
    _selectedLastDate = _dateTimeNow;
    _resultPicked.tagTime = TagTime.ninetyDaysPassed;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = true;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý khi chọn tag 1 tháng trước
  void _handleSelectedTagLastMonth() {
    final DateTime _endDayLastMonth =
        _today.subtract(Duration(days: _dateTimeNow.day));
    _selectedFirstDate =
        DateTime(_endDayLastMonth.year, _endDayLastMonth.month);
    _selectedLastDate = _endDayLastMonth;
    _resultPicked.tagTime = TagTime.lastMonth;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = true;
    _isSelectedTagLastYear = false;
    setState(() {});
  }

  /// Xử lý khi chọn tag 1 năm trước
  void _handleSelectedTagLastYear() {
    _selectedFirstDate = DateTime(_dateTimeNow.year - 1);
    _selectedLastDate = DateTime(_dateTimeNow.year - 1, 12, 31);
    _resultPicked.tagTime = TagTime.lastYear;

    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;

    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = true;
    setState(() {});
  }

  /// Xử lý khi nhấn chọn ngày sẽ mất tag time đã chọn trước đó, set tagTime = none
  void _refreshTagTime() {
    _isSelectedTagToday = false;
    _isSelectedTagCurrentMonth = false;
    _isSelectedTagCurrentYear = false;
    _isSelectedTagThirtyDaysPassed = false;
    _isSelectedTagYesterday = false;
    _isSelectedTagSevenDaysPassed = false;
    _isSelectedTagNinetyDaysPassed = false;
    _isSelectedTagLastMonth = false;
    _isSelectedTagLastYear = false;
    _resultPicked.tagTime = TagTime.none;
    setState(() {});
  }

  ///UI build Button hủy + Áp dụng
  Widget _buildButtonConfirm() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomButton(
            title: 'Hủy',
            onPressed: _handleCancel,
            colorTitle: Color(0xFF2C333A),
            colorButton: Color(0xFFF0F1F3)),
        CustomButton(
            title: 'Áp dụng',
            onPressed: _handleOk,
            colorTitle: Colors.white,
            colorButton: Color(0xFF28A745)),
      ],
    );
  }

  /// UI Tab Phổ biến
  Widget _buildTabCommon() {
    final TextStyle textStyle =
        TextStyle(color: Color(0xFF5A6271), fontSize: 17, fontFamily: 'Lato');
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TagTimeView(
                  title: 'Hôm nay',
                  onTap: _handleSelectedTagToday,
                  isSelected: _isSelectedTagToday),
              TagTimeView(
                  title: 'Tháng này',
                  onTap: _handleSelectedTagCurrentMonth,
                  isSelected: _isSelectedTagCurrentMonth),
              TagTimeView(
                  title: 'Năm này',
                  onTap: _handleSelectedTagCurrentYear,
                  isSelected: _isSelectedTagCurrentYear),
              TagTimeView(
                  title: '30 Ngày qua',
                  onTap: _handleSelectedTagThirtyDaysPassed,
                  isSelected: _isSelectedTagThirtyDaysPassed),
            ],
          ),
          const SizedBox(height: 20),
          Text('Tùy chỉnh', style: textStyle),
          const SizedBox(height: 15),
          _buildPicker(),
          const SizedBox(height: 50),
          _buildButtonConfirm(),
        ],
      ),
    );
  }

  ///UI Tab Ngày
  Widget _buildTabDate() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TagTimeView(
                  title: 'Hôm nay',
                  isSelected: _isSelectedTagToday,
                  onTap: _handleSelectedTagToday),
              TagTimeView(
                title: 'Hôm qua',
                isSelected: _isSelectedTagYesterday,
                onTap: _handleSelectedTagYesterday,
              ),
              TagTimeView(
                title: '7 ngày qua',
                isSelected: _isSelectedTagSevenDaysPassed,
                onTap: _handleSelectedTagSevenDaysPassed,
              ),
              TagTimeView(
                title: '30 Ngày qua',
                isSelected: _isSelectedTagThirtyDaysPassed,
                onTap: _handleSelectedTagThirtyDaysPassed,
              ),
              TagTimeView(
                title: '90 Ngày qua',
                isSelected: _isSelectedTagNinetyDaysPassed,
                onTap: _handleSelectedTagNinetyDaysPassed,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Tùy chỉnh',
            style: TextStyle(
                color: Color(0xFF5A6271), fontSize: 17, fontFamily: 'Lato'),
          ),
          const SizedBox(height: 15),
          _buildPicker(),
          const SizedBox(height: 10),
          _buildButtonConfirm(),
        ],
      ),
    );
  }

  ///UI Tab Tháng
  Widget _buildTabMonth() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TagTimeView(
                title: '30 Ngày qua',
                isSelected: _isSelectedTagThirtyDaysPassed,
                onTap: _handleSelectedTagThirtyDaysPassed,
              ),
              TagTimeView(
                title: 'Tháng này',
                isSelected: _isSelectedTagCurrentMonth,
                onTap: _handleSelectedTagCurrentMonth,
              ),
              TagTimeView(
                title: 'Tháng trước',
                isSelected: _isSelectedTagLastMonth,
                onTap: _handleSelectedTagLastMonth,
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            'Tùy chỉnh',
            style: TextStyle(
                color: Color(0xFF5A6271), fontSize: 17, fontFamily: 'Lato'),
          ),
          const SizedBox(height: 15),
          _buildPicker(),
          const SizedBox(height: 25),
          _buildDropdownTimeRangeSelect(
            'tháng',
            _buildDropdownSelectTime(
              _dropdownValueFromMonth,
              _handleDropdownFromMonthChanged,
              _listMonthRangeSelect,
              'Tháng ',
            ),
            _buildDropdownSelectTime(
              _dropdownValueToMonth,
              _handleDropdownToMonthChanged,
              _listMonthRangeSelect,
              'Tháng ',
            ),
          ),
          const SizedBox(height: 15),
          _buildButtonConfirm(),
        ],
      ),
    );
  }

  ///UI dropdown chọn thời gian sử dụng chung (Năm or Tháng)
  Widget _buildDropdownSelectTime(String dropdownValue,
      ValueChanged<String?>? onChanged, List<String> items, String itemName) {
    return Container(
      height: 38,
      width: 156,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
          border: Border.all(color: Color(0xFFE9EDF2))),
      child: DropdownButton<String>(
        value: dropdownValue,
        isExpanded: true,
        iconSize: 24,
        elevation: 16,
        dropdownColor: Colors.white,
        style: TextStyle(color: Color(0xFF2C333A)),
        underline: SizedBox(),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              itemName + value,
              style: TextStyle(
                  fontFamily: 'Lato', fontSize: 15, color: Color(0xFF2C333A)),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Xử lý nếu 2 giá trị dropdown trước hoặc cùng 1 tháng
  /// thì trả về 1 list gồm 2 phần tử gồm ngày bắt đầu + ngày cuối
  /// nếu không trả về 1 list null
  List<DateTime>? _getMonthTimeRangeDropdown(
      String dropdownValueFirst, String dropdownValueLast) {
    DateTime firstDate = DateTime(int.parse(dropdownValueFirst.split('/')[1]),
        int.parse(dropdownValueFirst.split('/')[0]));
    DateTime lastDate = DateTime(int.parse(dropdownValueLast.split('/')[1]),
        int.parse(dropdownValueLast.split('/')[0]));
    if (firstDate.isBefore(lastDate) || firstDate.isAtSameMomentAs(lastDate)) {
      if (lastDate.year == _dateTimeNow.year &&
          lastDate.month == _dateTimeNow.month) {
        lastDate = _dateTimeNow;
      } else {
        lastDate = DateTime(lastDate.year, lastDate.month,
            DayPicker.getDaysInMonth(lastDate.year, lastDate.month));
      }
      return <DateTime>[firstDate, lastDate];
    }
  }

  /// Xử lý khi thay đổi dropdown từ tháng, kiểm tra nếu tháng <= tới tháng sẽ range date
  void _handleDropdownFromMonthChanged(String? newValue) {
    if (newValue != null) {
      final List<DateTime>? _monthTimeRangeDropdown =
          _getMonthTimeRangeDropdown(newValue, _dropdownValueToMonth);
      if (_monthTimeRangeDropdown != null) {
        _dropdownValueFromMonth = newValue;
        _selectedFirstDate = _monthTimeRangeDropdown[0];
        _selectedLastDate = _monthTimeRangeDropdown[1];
        _refreshTagTime();
        setState(() {});
      }
    }
  }

  /// Xử lý khi thay đổi dropdown từ tháng, kiểm tra nếu tháng <= tới tháng sẽ range date
  void _handleDropdownToMonthChanged(String? newValue) {
    if (newValue != null) {
      final List<DateTime>? _monthTimeRangeDropdown =
          _getMonthTimeRangeDropdown(_dropdownValueFromMonth, newValue);
      if (_monthTimeRangeDropdown != null) {
        _dropdownValueToMonth = newValue;
        _selectedFirstDate = _monthTimeRangeDropdown[0];
        _selectedLastDate = _monthTimeRangeDropdown[1];
        _refreshTagTime();
        setState(() {});
      }
    }
  }

  ///UI Tab Năm
  Widget _buildTabYear() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TagTimeView(
                title: 'Năm này',
                isSelected: _isSelectedTagCurrentYear,
                onTap: _handleSelectedTagCurrentYear,
              ),
              TagTimeView(
                title: 'Năm trước',
                isSelected: _isSelectedTagLastYear,
                onTap: _handleSelectedTagLastYear,
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            'Tùy chỉnh',
            style: TextStyle(
                color: Color(0xFF5A6271), fontSize: 17, fontFamily: 'Lato'),
          ),
          const SizedBox(height: 15),
          _buildPicker(),
          _buildDropdownTimeRangeSelect(
            'năm',
            _buildDropdownSelectTime(
              _dropdownValueFromYear,
              _handleDropdownFromYearChanged,
              _listYearRangeSelect,
              '',
            ),
            _buildDropdownSelectTime(
              _dropdownValueToYear,
              _handleDropdownToYearChanged,
              _listYearRangeSelect,
              '',
            ),
          ),
          const SizedBox(height: 30),
          _buildButtonConfirm(),
        ],
      ),
    );
  }

  /// Xử lý khi thay đổi dropdown từ năm, kiểm tra nếu năm <= tới năm sẽ range date
  void _handleDropdownFromYearChanged(String? newValue) {
    if (newValue != null) {
      if (int.parse(newValue) <= int.parse(_dropdownValueToYear)) {
        _dropdownValueFromYear = newValue;
        _selectedFirstDate = DateTime(int.parse(newValue));
        if (int.parse(_dropdownValueToYear) == _dateTimeNow.year)
          _selectedLastDate = _dateTimeNow;
        else {
          _selectedLastDate = DateTime(int.parse(_dropdownValueToYear), 12, 31);
        }
        _refreshTagTime();
        setState(() {});
      }
    }
  }

  /// Xử lý khi thay đổi dropdown từ năm, kiểm tra nếu năm <= tới năm sẽ range date
  void _handleDropdownToYearChanged(String? newValue) {
    if (newValue != null) {
      if (int.parse(_dropdownValueFromYear) <= int.parse(newValue)) {
        _dropdownValueToYear = newValue;
        _selectedFirstDate = DateTime(int.parse(_dropdownValueFromYear));
        if (int.parse(_dropdownValueToYear) == _dateTimeNow.year)
          _selectedLastDate = _dateTimeNow;
        else {
          _selectedLastDate = DateTime(int.parse(_dropdownValueToYear), 12, 31);
        }
        _refreshTagTime();
        setState(() {});
      }
    }
  }

  /// UI Chọn time từ tháng(năm) tới tháng (năm)
  Widget _buildDropdownTimeRangeSelect(
      String titleTime, Widget dropdownFrom, Widget dropdownTo) {
    final TextStyle _textStyle = TextStyle(
      color: Color(0xFF929DAA),
      fontSize: 15,
      letterSpacing: 0.23,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Từ $titleTime:', style: _textStyle),
            const SizedBox(height: 7),
            dropdownFrom,
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tới $titleTime:', style: _textStyle),
            const SizedBox(height: 7),
            dropdownTo,
          ],
        )
      ],
    );
  }
}
