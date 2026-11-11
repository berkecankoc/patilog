import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:patilog/core/router/pet_care_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/router/care_record_changes.dart';

void main() {
  testWidgets('nested route scopes reuse the app-owned mutation notifier', (
    tester,
  ) async {
    final changes = CareRecordChanges();
    addTearDown(changes.dispose);
    late BuildContext flow;
    await tester.pumpWidget(
      CareRecordChangeScope(
        changes: changes,
        child: CareRecordChangeScope(
          child: Builder(
            builder: (context) {
              flow = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(CareRecordChanges.maybeOf(flow), same(changes));
    await tester.pumpWidget(const SizedBox());
    var calls = 0;
    changes.addListener(() => calls++);
    changes.changed('pet', PetCareTab.medications);
    expect(calls, 1);
  });

  testWidgets(
    'notifications for another pet cannot invalidate the current flow',
    (tester) async {
      late BuildContext flow;
      await tester.pumpWidget(
        PetCareChangeScope(
          petId: 'first',
          child: Builder(
            builder: (context) {
              flow = context;
              return const SizedBox();
            },
          ),
        ),
      );
      final changes = PetCareChanges.maybeOf(flow)!;
      PetCareChanges.recordChanged(
        flow,
        'other',
        PetCareTab.vetVisits,
        deletedId: 'foreign',
      );
      expect(changes.take(PetCareTab.vetVisits).deleted, isEmpty);
      expect(changes.take(PetCareTab.vaccinations).reload, isFalse);
      PetCareChanges.recordChanged(flow, 'first', PetCareTab.vetVisits);
      expect(changes.take(PetCareTab.vetVisits).reload, isTrue);
    },
  );
  test('visit edits invalidate only the source and linked record lists', () {
    final changes = PetCareChanges('pet');
    addTearDown(changes.dispose);
    changes.changed(PetCareTab.vetVisits);
    for (final tab in [
      PetCareTab.vetVisits,
      PetCareTab.vaccinations,
      PetCareTab.medications,
    ]) {
      expect(changes.take(tab).reload, isTrue);
      expect(changes.take(tab).reload, isFalse);
    }
    expect(changes.take(PetCareTab.weightHistory).reload, isFalse);
    expect(changes.take(PetCareTab.profile).reload, isFalse);
  });
  test('known deletion carries its ID without requiring a source read', () {
    final changes = PetCareChanges('pet');
    addTearDown(changes.dispose);
    changes.changed(PetCareTab.vetVisits, deletedId: 'visit');
    final source = changes.take(PetCareTab.vetVisits);
    expect(source.reload, isFalse);
    expect(source.deleted, {'visit'});
    expect(changes.take(PetCareTab.vaccinations).reload, isTrue);
  });
  test(
    'locally updated measurements invalidate the profile without reloading history',
    () {
      final changes = PetCareChanges('pet');
      addTearDown(changes.dispose);
      changes.changed(PetCareTab.weightHistory, listIsCurrent: true);
      expect(changes.take(PetCareTab.weightHistory).reload, isFalse);
      expect(changes.take(PetCareTab.profile).reload, isTrue);
    },
  );
}
