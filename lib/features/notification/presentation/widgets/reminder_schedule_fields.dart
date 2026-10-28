import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/utils/time_input_formatter.dart';
import 'package:petlytics/features/notification/domain/entities/vaccination_reminder_schedule.dart';

String reminderScheduleSummary(VaccinationReminderSchedule schedule) {
  final days = schedule.daysBefore
      .map(
        (day) => day == 0
            ? 'Vaccination day'
            : '$day ${day == 1 ? 'day' : 'days'} before',
      )
      .join(', ');
  return '$days · ${reminderTime(schedule.minuteOfDay)}';
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
      Text('Remind me', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      const Text('Choose up to 3 reminder days.'),
      const SizedBox(height: AppSpacing.sm),
      FormField<Set<int>>(
        initialValue: _days,
        validator: (_) => _days.isEmpty
            ? 'Select at least one day'
            : _days.length > VaccinationReminderSchedule.maxReminderDays
            ? 'Choose up to 3 reminder days'
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
                          ? 'Vaccination day'
                          : '$day ${day == 1 ? 'day' : 'days'} before',
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
        decoration: const InputDecoration(
          labelText: 'Reminder time',
          hintText: 'HH:mm',
          helperText: '24-hour time on this device.',
          errorMaxLines: 3,
        ),
        validator: (_) => _minute != null ? null : 'Use 00:00–23:59',
        onChanged: (_) => _changed(),
      ),
    ],
  );
}
