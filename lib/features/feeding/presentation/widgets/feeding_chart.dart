import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/feeding/domain/entities/feeding_daily_total.dart';
import 'package:petlytics/features/feeding/presentation/utils/feeding_display.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

class FeedingChart extends StatelessWidget {
  final List<FeedingDailyTotal> totals;
  final int days;
  final bool busy;
  final ValueChanged<int> onRangeChanged;
  const FeedingChart({
    super.key,
    required this.totals,
    required this.days,
    this.busy = false,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final max = totals.fold<double>(
      0,
      (value, day) => math.max(value, day.amountGrams ?? 0),
    );
    final raw = max / 3;
    final magnitude = raw > 0
        ? math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble()
        : 1.0;
    final fraction = raw / magnitude;
    final step = math.max(
      0.1,
      magnitude *
          (fraction <= 1
              ? 1
              : fraction <= 2
              ? 2
              : fraction <= 5
              ? 5
              : 10),
    );
    final top = math.max(step, (max / step).ceil() * step);
    final style = theme.textTheme.labelSmall!;
    var labelWidth = 0.0;
    for (var tick = 0.0; tick <= top + step / 2; tick += step) {
      final painter = TextPainter(
        text: TextSpan(text: feedingAmount(context, tick), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      labelWidth = math.max(labelWidth, painter.width);
      painter.dispose();
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeading(
              title: s.feedingTrend,
              icon: Icons.bar_chart_outlined,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final value in [7, 30])
                    ButtonSegment(
                      value: value,
                      label: Text(s.feedingDays(value)),
                    ),
                ],
                selected: {days},
                onSelectionChanged: busy
                    ? null
                    : (value) => onRangeChanged(value.single),
              ),
            ),
            const SizedBox(height: 20),
            if (max == 0)
              Text(s.feedingNoRecordsDescription)
            else
              Semantics(
                image: true,
                label: s.feedingTrend,
                value: totals
                    .map(
                      (day) => day.amountGrams == null
                          ? s.calendarDayDescription(
                              MaterialLocalizations.of(
                                context,
                              ).formatShortDate(day.date),
                              s.noDoseRecord,
                            )
                          : s.feedingEntrySummary(
                              MaterialLocalizations.of(
                                context,
                              ).formatShortDate(day.date),
                              feedingAmount(context, day.amountGrams!),
                            ),
                    )
                    .join('\n'),
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 190 + MediaQuery.textScalerOf(context).scale(12),
                    child: BarChart(
                      duration: Duration.zero,
                      BarChartData(
                        maxY: top,
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: step,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            axisNameWidget: Text(
                              'g',
                              style: theme.textTheme.bodySmall,
                            ),
                            axisNameSize:
                                MediaQuery.textScalerOf(context).scale(18) + 8,
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: step,
                              reservedSize: labelWidth + 12,
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 8,
                                ),
                                child: Text(
                                  feedingAmount(context, value),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: style,
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: [
                          for (final (index, day) in totals.indexed)
                            BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: day.amountGrams ?? 0,
                                  width: days == 7 ? 14 : 5,
                                  color: theme.colorScheme.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                        ],
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final day = totals[group.x];
                              return BarTooltipItem(
                                '${MaterialLocalizations.of(context).formatShortDate(day.date)}\n${day.amountGrams == null ? s.noDoseRecord : s.feedingGrams(feedingAmount(context, day.amountGrams!))}',
                                TextStyle(
                                  color: theme.colorScheme.onInverseSurface,
                                ),
                              );
                            },
                            getTooltipColor: (_) =>
                                theme.colorScheme.inverseSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (totals.isNotEmpty) ...[
              SizedBox(
                height:
                    16 +
                    MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                        (style.height ?? 1.2) /
                        2,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.MMMd(locale).format(totals.first.date),
                      style: style,
                    ),
                  ),
                  Text(
                    DateFormat.MMMd(locale).format(totals.last.date),
                    style: style,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(s.feedingChartHint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
