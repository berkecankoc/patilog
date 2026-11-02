import 'package:flutter/material.dart';

/// Shared appearance for the daily tracking/catalog views.
class AppViewSelector extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  const AppViewSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
    expandedInsets: EdgeInsets.zero,
    showSelectedIcon: false,
    segments: [
      for (final (index, label) in labels.indexed)
        ButtonSegment(
          value: index,
          label: Text(label, textAlign: TextAlign.center),
        ),
    ],
    selected: {selectedIndex},
    onSelectionChanged: onSelected == null
        ? null
        : (value) => onSelected!(value.single),
  );
}
