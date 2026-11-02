String calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String instantKey(DateTime date) {
  final utc = date.toUtc();
  final value = utc.toIso8601String();
  // Fixed precision keeps SQLite text ordering correct at submillisecond edges.
  return utc.microsecond == 0 ? value.replaceFirst('Z', '000Z') : value;
}

String? optionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
