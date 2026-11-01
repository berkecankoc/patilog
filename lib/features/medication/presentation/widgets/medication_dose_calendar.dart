import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose.dart';
import 'package:petlytics/features/medication/domain/entities/medication_dose_log.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_state.dart';
import 'package:petlytics/features/medication/presentation/widgets/medication_doses.dart';

class MedicationDoseCalendar extends StatelessWidget {
  final MedicationsLoaded state;

  const MedicationDoseCalendar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MedicationCubit>();
    final calendar = state.calendar!;
    final month = calendar.month;
    final dates = MaterialLocalizations.of(context);
    final busy = state.pendingAction != null || state.isRefreshing;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (month.weekday - dates.firstDayOfWeekIndex) % 7;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final byDay = <int, List<MedicationDose>>{};
    for (final dose in calendar.doses) {
      byDay.putIfAbsent(dose.scheduledDate.day, () => []).add(dose);
    }

    List<(IconData, String)> statuses(int day) {
      final doses = byDay[day] ?? const [];
      if (doses.isEmpty) return [];
      if (DateTime(
        month.year,
        month.month,
        day,
      ).isAfter(DateUtils.dateOnly(state.currentTime))) {
        return [
          (
            Icons.schedule_outlined,
            AppLocalizations.of(context).scheduledDoseCount(doses.length),
          ),
        ];
      }
      if (!calendar.hasLoaded) {
        return [
          (
            Icons.hourglass_empty,
            AppLocalizations.of(context).doseRecordsUnavailable,
          ),
        ];
      }
      final given = doses
          .where((dose) => dose.log?.status == MedicationDoseStatus.given)
          .length;
      final skipped = doses
          .where((dose) => dose.log?.status == MedicationDoseStatus.skipped)
          .length;
      final missing = doses.length - given - skipped;
      return [
        if (given > 0)
          (
            Icons.check_circle_outline,
            AppLocalizations.of(context).givenDoseCount(given),
          ),
        if (skipped > 0)
          (
            Icons.remove_circle_outline,
            AppLocalizations.of(context).skippedDoseCount(skipped),
          ),
        if (missing > 0)
          (
            Icons.radio_button_unchecked,
            AppLocalizations.of(context).missingDoseCount(missing),
          ),
      ];
    }

    Widget dayButton(int day) {
      final date = DateTime(month.year, month.month, day);
      final selected = DateUtils.isSameDay(date, state.doses.date);
      final indicators = statuses(day);
      final label = AppLocalizations.of(context).calendarDayDescription(
        dates.formatFullDate(date),
        indicators.isEmpty
            ? AppLocalizations.of(context).noScheduledDoses
            : indicators.map((item) => item.$2).join(', '),
      );
      return Semantics(
        label: label,
        button: true,
        selected: selected,
        enabled: !busy,
        onTap: busy ? null : () => cubit.selectCalendarDay(date),
        child: ExcludeSemantics(
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: selected
                  ? BorderSide(color: Theme.of(context).colorScheme.primary)
                  : BorderSide.none,
            ),
            child: InkWell(
              key: ValueKey(('dose-calendar-day', date)),
              borderRadius: BorderRadius.circular(12),
              onTap: busy ? null : () => cubit.selectCalendarDay(date),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: largeText
                    ? Row(
                        children: [
                          Expanded(child: Text(dates.formatMediumDate(date))),
                          Wrap(
                            spacing: 4,
                            children: [
                              for (final item in indicators)
                                Icon(item.$1, size: 20),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            '$day',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 1,
                            runSpacing: 2,
                            children: [
                              for (final item in indicators)
                                Icon(item.$1, size: 12),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: AppLocalizations.of(context).previousMonth,
              onPressed: busy
                  ? null
                  : () => cubit.loadCalendar(
                      DateTime(month.year, month.month - 1),
                    ),
              icon: const Icon(Icons.chevron_left),
            ),
            Flexible(
              child: Text(
                dates.formatMonthYear(month),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context).nextMonth,
              onPressed: busy
                  ? null
                  : () => cubit.loadCalendar(
                      DateTime(month.year, month.month + 1),
                    ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed:
                busy || DateUtils.isSameDay(state.doses.date, state.currentTime)
                ? null
                : () async {
                    final now = cubit.now();
                    if (month.year != now.year || month.month != now.month) {
                      await cubit.loadCalendar(now);
                    }
                    cubit.selectCalendarDay(now);
                  },
            icon: const Icon(Icons.today_outlined),
            label: Text(AppLocalizations.of(context).goToToday),
          ),
        ),
        if (calendar.isLoading)
          LinearProgressIndicator(
            semanticsLabel: AppLocalizations.of(context).loadingMonthRecords,
          ),
        if (calendar.error != null)
          AppErrorFeedback(
            message: AppLocalizations.of(context).doseLoadFailed,
            retryLabel: AppLocalizations.of(context).retryCalendar,
            onRetry: () => cubit.loadCalendar(month),
          ),
        if (largeText) ...[
          for (var day = 1; day <= days; day++)
            if (byDay.containsKey(day) || day == state.doses.date.day)
              dayButton(day),
        ] else ...[
          Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      dates.narrowWeekdays[(index + dates.firstDayOfWeekIndex) %
                          7],
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < (days + offset + 6) ~/ 7; week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < 7; index++)
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child:
                              week * 7 + index - offset + 1 < 1 ||
                                  week * 7 + index - offset + 1 > days
                              ? const SizedBox.shrink()
                              : dayButton(week * 7 + index - offset + 1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final item in [
              (
                Icons.check_circle_outline,
                AppLocalizations.of(context).doseGiven,
              ),
              (
                Icons.remove_circle_outline,
                AppLocalizations.of(context).doseSkipped,
              ),
              (
                Icons.radio_button_unchecked,
                AppLocalizations.of(context).noDoseRecord,
              ),
              (Icons.schedule_outlined, AppLocalizations.of(context).scheduled),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          dates.formatFullDate(state.doses.date),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (state.doses.doses.isEmpty)
          Text(AppLocalizations.of(context).noCalendarDayDoses),
        for (final dose in state.doses.doses)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MedicationDoseTile(
              key: ValueKey((
                dose.period.id,
                dose.scheduledDate,
                dose.scheduledMinute,
              )),
              dose: dose,
              known: state.doses.hasLoaded && !state.doses.isLoading,
              loading: state.doses.isLoading,
              busy: busy,
            ),
          ),
      ],
    );
  }
}
