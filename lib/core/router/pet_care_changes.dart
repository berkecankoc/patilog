import 'package:flutter/widgets.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';

/// Invalidations live for one pet flow, including its pushed forms/details.
class PetCareChanges extends ChangeNotifier {
  final String petId;
  final _dirty = <PetCareTab>{};
  final _deleted = <PetCareTab, Set<String>>{};

  PetCareChanges(this.petId);

  void changed(
    PetCareTab tab, {
    String? deletedId,
    bool listIsCurrent = false,
  }) {
    if (!listIsCurrent) {
      if (deletedId == null) {
        _dirty.add(tab);
      } else {
        (_deleted[tab] ??= {}).add(deletedId);
      }
    }
    switch (tab) {
      case PetCareTab.profile:
        _dirty.add(PetCareTab.weightHistory);
      case PetCareTab.weightHistory:
        _dirty.add(PetCareTab.profile);
      case PetCareTab.vetVisits:
        _dirty.addAll([PetCareTab.vaccinations, PetCareTab.medications]);
      case PetCareTab.vaccinations || PetCareTab.medications:
        break;
    }
    notifyListeners();
  }

  ({bool reload, Set<String> deleted}) take(PetCareTab tab) =>
      (reload: _dirty.remove(tab), deleted: _deleted.remove(tab) ?? {});

  static PetCareChanges? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_PetCareChangesProvider>()
      ?.notifier;

  static void recordChanged(
    BuildContext context,
    String petId,
    PetCareTab tab, {
    String? deletedId,
    bool listIsCurrent = false,
  }) {
    final changes = maybeOf(context);
    if (changes?.petId == petId) {
      changes!.changed(tab, deletedId: deletedId, listIsCurrent: listIsCurrent);
    }
  }
}

class PetCareChangeScope extends StatefulWidget {
  final String petId;
  final Widget child;
  const PetCareChangeScope({
    super.key,
    required this.petId,
    required this.child,
  });

  @override
  State<PetCareChangeScope> createState() => _PetCareChangeScopeState();
}

class _PetCareChangeScopeState extends State<PetCareChangeScope> {
  late final _changes = PetCareChanges(widget.petId);
  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _PetCareChangesProvider(notifier: _changes, child: widget.child);
}

class _PetCareChangesProvider extends InheritedNotifier<PetCareChanges> {
  const _PetCareChangesProvider({
    required super.notifier,
    required super.child,
  });
}
