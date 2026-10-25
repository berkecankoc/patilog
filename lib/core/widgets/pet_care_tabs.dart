import 'package:flutter/material.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';

class PetCareTabs extends InheritedWidget {
  final PetCareTab active;
  final bool Function(PetCareTab) onSelect;
  final VoidCallback onExit;

  const PetCareTabs({
    super.key,
    required this.active,
    required this.onSelect,
    required this.onExit,
    required super.child,
  });

  static PetCareTabs? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PetCareTabs>();

  @override
  bool updateShouldNotify(PetCareTabs oldWidget) => active != oldWidget.active;
}

PreferredSizeWidget? petCareAppBar(
  BuildContext context, {
  required Widget title,
  double? toolbarHeight,
  bool busy = false,
  List<Widget> actions = const [],
  Widget? progress,
}) {
  // Embedded tabs share the hub's persistent app bar.
  if (PetCareTabs.maybeOf(context) != null) return null;
  return AppBar(
    title: title,
    toolbarHeight: toolbarHeight,
    leading: busy
        ? const IconButton(onPressed: null, icon: BackButtonIcon())
        : null,
    actions: actions,
    bottom: progress != null
        ? PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: progress,
          )
        : null,
  );
}
