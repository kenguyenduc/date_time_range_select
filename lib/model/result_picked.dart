enum TagTime {
  none,
  today,
  yesterday,
  currentMonth,
  lastMonth,
  currentYear,
  lastYear,
  sevenDaysPassed,
  thirtyDaysPassed,
  ninetyDaysPassed
}

class ResultPicked {
  TagTime? tagTime;
  DateTime? selectedFirstDate;
  DateTime? selectedLastDate;

  ResultPicked({this.tagTime, this.selectedFirstDate, this.selectedLastDate});
}
