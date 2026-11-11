import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/utils/time_input_formatter.dart';
import 'package:patilog/features/notification/domain/entities/vaccination_reminder_schedule.dart';

String reminderScheduleSummary(
  AppLocalizations strings,
  VaccinationReminderSchedule schedule,
) {
  final days = schedule.daysBefore
      .map(
        (day) =>
            day == 0 ? strings.vaccinationDay : strings.reminderDaysBefore(day),
      )
      .join(', ');
  return strings.reminderScheduleSummary(
    days,
    reminderTime(schedule.minuteOfDay),
  );
}

String reminderTime(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class ReminderScheduleFields extends StatefulWidget {
  final VaccinationReminderSchedule initialValue;
  final ValueChanged<VaccinationReminderSchedule> onChanged;
  const ReminderScheduleFields({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<ReminderScheduleFields> createState() => _ReminderScheduleFieldsState();
}

class _ReminderScheduleFieldsState extends State<ReminderScheduleFields> {
  late final _days = {...widget.initialValue.daysBefore};
  late final _time = TextEditingController(
    text: reminderTime(widget.initialValue.minuteOfDay),
  );

  bool get _atDayLimit =>
      _days.length >= VaccinationReminderSchedule.maxReminderDays;

  int? get _minute {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(_time.text);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    return hour < 24 && minute < 60 ? hour * 60 + minute : null;
  }

  void _changed() => widget.onChanged(
    VaccinationReminderSchedule(
      daysBefore: _days.toList(),
      minuteOfDay: _minute ?? -1,
    ),
  );

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocalizations.of(context).remindMe,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(AppLocalizations.of(context).reminderDayLimitHint),
      const SizedBox(height: AppSpacing.sm),
      FormField<Set<int>>(
        initialValue: _days,
        validator: (_) => _days.isEmpty
            ? AppLocalizations.of(context).reminderDayRequired
            : _days.length > VaccinationReminderSchedule.maxReminderDays
            ? AppLocalizations.of(context).reminderDayLimit
            : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final day
                    in VaccinationReminderSchedule.availableDaysBefore)
                  FilterChip(
                    key: ValueKey('reminder-day-$day'),
                    label: Text(
                      day == 0
                          ? AppLocalizations.of(context).vaccinationDay
                          : AppLocalizations.of(
                              context,
                            ).reminderDaysBefore(day),
                    ),
                    selected: _days.contains(day),
                    onSelected: _days.contains(day) || !_atDayLimit
                        ? (selected) {
                            if (selected && _atDayLimit) {
                              return;
                            }
                            setState(
                              () =>
                                  selected ? _days.add(day) : _days.remove(day),
                            );
                            field.didChange(Set.of(_days));
                            field.validate();
                            _changed();
                          }
                        : null,
                  ),
              ],
            ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        key: const Key('reminder-time'),
        controller: _time,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: const [TimeInputFormatter()],
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).reminderTime,
          hintText: AppLocalizations.of(context).timeFormatHint,
          helperText: AppLocalizations.of(context).time24DeviceHint,
          errorMaxLines: 3,
        ),
        validator: (_) => _minute != null
            ? null
            : AppLocalizations.of(context).timeRangeInvalid,
        onChanged: (_) => _changed(),
      ),
    ],
  );
}
