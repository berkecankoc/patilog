import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:petlytics/core/router/care_record_changes.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';
import 'package:petlytics/features/notification/presentation/cubit/notification_cubit.dart';

/// App-level lifetime, independent of the currently visible care tab or form.
class NotificationRuntime extends StatefulWidget {
  final Widget child;
  const NotificationRuntime({super.key, required this.child});
  @override
  State<NotificationRuntime> createState() => _NotificationRuntimeState();
}

class _NotificationRuntimeState extends State<NotificationRuntime>
    with WidgetsBindingObserver {
  CareRecordChanges? _changes;
  Timer? _clock;
  NotificationCubit get _cubit => context.read<NotificationCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_cubit.refreshForClockChange());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_cubit.initialize());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = CareRecordChanges.maybeOf(context);
    if (changes != _changes) {
      _changes?.removeListener(_onChange);
      _changes = changes;
      changes?.addListener(_onChange);
    }
  }

  void _onChange() {
    final change = _changes?.last;
    if (change == null) return;
    final petId = change.petId;
    if (change.petDeleted && petId != null) {
      unawaited(_cubit.removeDeleted(petId: petId, petDeleted: true));
    } else if (change.tab == PetCareTab.vaccinations &&
        change.deletedId != null &&
        petId != null) {
      unawaited(
        _cubit.removeDeleted(petId: petId, vaccinationId: change.deletedId),
      );
    } else if (change.tab == PetCareTab.medications &&
        change.deletedId != null &&
        petId != null) {
      unawaited(
        _cubit.removeDeleted(petId: petId, medicationId: change.deletedId),
      );
    } else if (change.tab != PetCareTab.weightHistory &&
        !(change.tab == PetCareTab.vetVisits && change.deletedId != null)) {
      unawaited(_cubit.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_cubit.refresh());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _changes?.removeListener(_onChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
