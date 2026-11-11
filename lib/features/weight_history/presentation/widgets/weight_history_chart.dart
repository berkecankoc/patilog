import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/theme/app_spacing.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_section_heading.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';
import 'package:patilog/features/weight_history/presentation/utils/weight_chart_data.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

class WeightHistoryChart extends StatefulWidget {
  final List<WeightEntry> entries;

  const WeightHistoryChart({super.key, required this.entries});

  @override
  State<WeightHistoryChart> createState() => _WeightHistoryChartState();
}

class _WeightHistoryChartState extends State<WeightHistoryChart> {
  WeightChartRange _range = WeightChartRange.threeMonths;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final dates = MaterialLocalizations.of(context);
    final points = weightChartEntries(widget.entries, _range, DateTime.now());
    String label(WeightChartRange range) => switch (range) {
      WeightChartRange.month => strings.weightChartOneMonth,
      WeightChartRange.threeMonths => strings.weightChartThreeMonths,
      WeightChartRange.sixMonths => strings.weightChartSixMonths,
      WeightChartRange.all => strings.weightChartAll,
    };
    String shortLabel(WeightChartRange range) => switch (range) {
      WeightChartRange.month => strings.weightChartMonthsShort(1),
      WeightChartRange.threeMonths => strings.weightChartMonthsShort(3),
      WeightChartRange.sixMonths => strings.weightChartMonthsShort(6),
      WeightChartRange.all => strings.weightChartAll,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeading(
              title: strings.weightTrend,
              icon: Icons.show_chart,
            ),
            VerticalGap.sm,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final range in WeightChartRange.values) ...[
                    if (range != WeightChartRange.values.first)
                      const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      key: ValueKey(range),
                      showCheckmark: false,
                      labelPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      tooltip: label(range),
                      label: Text(
                        shortLabel(range),
                        semanticsLabel: label(range),
                        maxLines: 1,
                        softWrap: false,
                      ),
                      selected: _range == range,
                      onSelected: (_) => setState(() => _range = range),
                    ),
                  ],
                ],
              ),
            ),
            VerticalGap.md,
            if (points.isEmpty) ...[
              Text(strings.weightChartEmpty),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _range = WeightChartRange.all),
                  child: Text(strings.weightChartShowAll),
                ),
              ),
            ] else ...[
              if (points.length > 1) ...[
                Text(
                  strings.weightChartChange(
                    '${points.last.weight > points.first.weight ? '+' : ''}${localizedWeight(points.last.weight - points.first.weight, locale)}',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                VerticalGap.md,
              ],
              _WeightPlot(points: points),
              VerticalGap.md,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      dates.formatShortDate(points.first.measuredAt.toLocal()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (points.length > 1)
                    Expanded(
                      child: Text(
                        dates.formatShortDate(points.last.measuredAt.toLocal()),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              VerticalGap.md,
              Text(
                points.length == 1
                    ? strings.weightChartSinglePoint
                    : strings.weightChartDailyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightPlot extends StatelessWidget {
  final List<WeightEntry> points;

  const _WeightPlot({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final strings = AppLocalizations.of(context);
    final dates = MaterialLocalizations.of(context);
    final bounds = weightChartBounds(points);
    final firstDay = weightChartDay(points.first.measuredAt);
    final days = weightChartDay(
      points.last.measuredAt,
    ).difference(firstDay).inDays;
    final scaler = MediaQuery.textScalerOf(context);
    final axisStyle = theme.textTheme.bodySmall!;
    String axisLabel(double value) => value.abs() >= 10000
        ? NumberFormat.compact(locale: locale.toLanguageTag()).format(value)
        : localizedWeight(value, locale);
    final axisWidth = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    );
    var labelWidth = 0.0;
    final steps = ((bounds.max - bounds.min) / bounds.interval).round();
    // The highest value can be shorter than an intermediate decimal label.
    for (var index = 0; index <= steps; index++) {
      axisWidth.text = TextSpan(
        text: axisLabel(bounds.min + index * bounds.interval),
        style: axisStyle,
      );
      axisWidth.layout();
      labelWidth = math.max(labelWidth, axisWidth.width);
    }
    final reservedSize =
        labelWidth.ceilToDouble() + AppSpacing.sm + AppSpacing.xs;
    final labelOverhang = axisWidth.height / 2;
    axisWidth.dispose();

    return Padding(
      // The bottom tick label is centered on the plot's lower edge.
      padding: EdgeInsets.only(bottom: labelOverhang),
      child: Semantics(
        image: true,
        label: strings.weightChartSemantics,
        child: ExcludeSemantics(
          child: SizedBox(
            height: 200 + scaler.scale(20),
            child: LineChart(
              key: ValueKey(Object.hashAll(points)),
              // New measurements must not animate through fabricated values.
              duration: Duration.zero,
              LineChartData(
                minX: points.length == 1 ? -1 : 0,
                maxX: points.length == 1 ? 1 : days.toDouble(),
                minY: bounds.min,
                maxY: bounds.max,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: bounds.interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text('kg', style: axisStyle),
                    axisNameSize: scaler.scale(18) + AppSpacing.sm,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: reservedSize,
                      interval: bounds.interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: AppSpacing.sm,
                        child: Text(
                          axisLabel(value),
                          style: axisStyle,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (final point in points)
                        FlSpot(
                          weightChartDay(
                            point.measuredAt,
                          ).difference(firstDay).inDays.toDouble(),
                          point.weight,
                        ),
                    ],
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    isCurved: false,
                    dotData: FlDotData(
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 4,
                        color: theme.colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 24,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    maxContentWidth: 200,
                    tooltipBorderRadius: BorderRadius.circular(12),
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          '${localizedWeight(points[spot.spotIndex].weight, locale)} kg\n${dates.formatShortDate(points[spot.spotIndex].measuredAt.toLocal())}',
                          theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                            fontSize: scaler.scale(
                              theme.textTheme.bodyMedium!.fontSize!,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
