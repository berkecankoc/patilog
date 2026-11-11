import 'package:flutter/widgets.dart';
import 'package:patilog/core/router/pet_care_tab.dart';

/// Successful writes can invalidate the retained global lists without loading
/// them when the app was opened directly on a pet-specific route.
class CareRecordChanges extends ChangeNotifier {
  ({
    String? petId,
    PetCareTab tab,
    String? deletedId,
    bool petDeleted,
    bool globalListIsCurrent,
  })?
  last;

  void changed(
    String? petId,
    PetCareTab tab, {
    String? deletedId,
    bool petDeleted = false,
    bool globalListIsCurrent = false,
  }) {
    last = (
      petId: petId,
      tab: tab,
      deletedId: deletedId,
      petDeleted: petDeleted,
      globalListIsCurrent: globalListIsCurrent,
    );
    notifyListeners();
  }

  static CareRecordChanges? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_CareRecordChangesProvider>()
      ?.notifier;
}

class CareRecordChangeScope extends StatefulWidget {
  final Widget child;
  final CareRecordChanges? changes;
  const CareRecordChangeScope({super.key, required this.child, this.changes});
  @override
  State<CareRecordChangeScope> createState() => _CareRecordChangeScopeState();
}

class _CareRecordChangeScopeState extends State<CareRecordChangeScope> {
  CareRecordChanges? _owned;
  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inherited = CareRecordChanges.maybeOf(context);
    if (widget.changes == null && inherited != null) return widget.child;
    return _CareRecordChangesProvider(
      notifier: widget.changes ?? (_owned ??= CareRecordChanges()),
      child: widget.child,
    );
  }
}

class _CareRecordChangesProvider extends InheritedNotifier<CareRecordChanges> {
  const _CareRecordChangesProvider({
    required super.notifier,
    required super.child,
  });
}
