// Calendar arithmetic uses UTC components, not elapsed local-midnight durations
// that can be shorter/longer than 24 hours around daylight-saving transitions.
int calendarDayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
