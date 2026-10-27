import 'package:flutter/widgets.dart';
import 'package:petlytics/core/router/pet_care_tab.dart';

/// Successful writes can invalidate the retained global lists without loading
/// them when the app was opened directly on a pet-specific route.
class CareRecordChanges extends ChangeNotifier {
  ({String? petId, PetCareTab tab, String? deletedId, bool petDeleted})? last;

  void changed(
    String? petId,
    PetCareTab tab, {
    String? deletedId,
    bool petDeleted = false,
  }) {
    last = (
      petId: petId,
      tab: tab,
      deletedId: deletedId,
      petDeleted: petDeleted,
    );
    notifyListeners();
  }

  static CareRecordChanges? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_CareRecordChangesProvider>()
      ?.notifier;
}

class CareRecordChangeScope extends StatefulWidget {
  final Widget child;
  const CareRecordChangeScope({super.key, required this.child});
  @override
  State<CareRecordChangeScope> createState() => _CareRecordChangeScopeState();
}

class _CareRecordChangeScopeState extends State<CareRecordChangeScope> {
  final _changes = CareRecordChanges();
  @override
  void dispose() {
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CareRecordChangesProvider(notifier: _changes, child: widget.child);
}

class _CareRecordChangesProvider extends InheritedNotifier<CareRecordChanges> {
  const _CareRecordChangesProvider({
    required super.notifier,
    required super.child,
  });
}
