import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';

class MedicationClock extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onResume;
  final bool active;
  const MedicationClock({
    super.key,
    required this.child,
    required this.onResume,
    this.active = true,
  });
  @override
  State<MedicationClock> createState() => _MedicationClockState();
}

class _MedicationClockState extends State<MedicationClock>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (widget.active) {
        context.read<MedicationCubit>().refreshForClockChange();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) widget.onResume();
  }

  @override
  void didUpdateWidget(MedicationClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      context.read<MedicationCubit>().refreshForClockChange();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
