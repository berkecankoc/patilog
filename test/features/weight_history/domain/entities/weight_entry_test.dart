import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/features/weight_history/domain/entities/weight_entry.dart';

void main() {
  final measuredAt = DateTime(2026, 10, 12);
  final entry = WeightEntry(
    id: 'entry-1',
    petId: 'pet-1',
    weight: 5.4,
    measuredAt: measuredAt,
  );

  test('equivalent measurements compare equally', () {
    expect(
      WeightEntry(
        id: entry.id,
        petId: entry.petId,
        weight: entry.weight,
        measuredAt: DateTime(2026, 10, 12),
      ),
      entry,
    );
  });

  test('a weight correction changes equality even with the same entry ID', () {
    expect(
      WeightEntry(
        id: entry.id,
        petId: entry.petId,
        weight: 5.8,
        measuredAt: entry.measuredAt,
      ),
      isNot(entry),
    );
  });

  test(
    'a measurement date correction changes equality with the same entry ID',
    () {
      expect(
        WeightEntry(
          id: entry.id,
          petId: entry.petId,
          weight: entry.weight,
          measuredAt: DateTime(2026, 10, 11),
        ),
        isNot(entry),
      );
    },
  );
}
