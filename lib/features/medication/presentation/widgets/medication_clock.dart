import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/features/medication/presentation/cubit/medication_cubit.dart';

class MedicationClock extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onResume;
  const MedicationClock({
    super.key,
    required this.child,
    required this.onResume,
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
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => context.read<MedicationCubit>().refreshForClockChange(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onResume();
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
