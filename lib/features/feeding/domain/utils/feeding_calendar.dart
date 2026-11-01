// Copy calendar components; local-midnight durations can vary across DST.
int feedingDayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
