import 'package:equatable/equatable.dart';

enum MedicationDoseStatus { given, skipped }

final class MedicationDoseLog extends Equatable {
  /// Together these three fields identify one scheduled dose; no generated ID
  /// is needed when correcting or clearing its result.
  final String periodId;

  /// Calendar day without UTC conversion; the minute is local, in 0–1439.
  final DateTime scheduledDate;
  final int scheduledMinute;

  final MedicationDoseStatus status;

  /// An actual instant, present exactly when [status] is given. Unlike the
  /// scheduled calendar day and local minute, this can be stored in UTC.
  final DateTime? givenAt;

  const MedicationDoseLog({
    required this.periodId,
    required this.scheduledDate,
    required this.scheduledMinute,
    required this.status,
    this.givenAt,
  });

  @override
  List<Object?> get props => [
    periodId,
    scheduledDate,
    scheduledMinute,
    status,
    givenAt,
  ];
}
