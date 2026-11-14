import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/router/app_router.dart';
import 'package:patilog/core/router/app_routes.dart';
import 'package:patilog/core/utils/weight_utils.dart';
import 'package:patilog/features/weight_history/domain/entities/weight_entry.dart';

import '../../../../helpers/settings_test_harness.dart';

void main() {
  late SettingsTestHarness app;
  setUpAll(SettingsTestHarness.initialize);
  setUp(() {
    app = SettingsTestHarness()..register();
    app.care.measurements = [
      WeightEntry(
        id: 'weight',
        petId: 'pet',
        weight: 4.5,
        measuredAt: app.care.today,
      ),
    ];
  });

  Future<void> choose(WidgetTester tester, String label) async {
    final option = find.widgetWithText(RadioListTile<WeightUnit>, label);
    await tester.scrollUntilVisible(option, 200);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  testWidgets('pounds persist and convert weights across the app', (
    tester,
  ) async {
    await app.pump(tester);
    await choose(tester, 'Pounds (lb)');
    expect(app.storedWeightUnit, WeightUnit.pound);
    appRouter.go(AppRoutes.allWeightHistory);
    await tester.pumpAndSettle();
    expect(find.text('9.921 lb'), findsOneWidget);
    expect(find.textContaining('kg'), findsNothing);
  });

  testWidgets('a failed unit save keeps kilograms and retries the target', (
    tester,
  ) async {
    app.failWeightUnitSave = true;
    await app.pump(tester);
    await choose(tester, 'Pounds (lb)');
    expect(find.text('Failed to save weight unit'), findsOneWidget);
    expect(app.cubit.state.weightUnit, WeightUnit.kilogram);
    app.failWeightUnitSave = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to save weight unit'), findsNothing);
    expect(app.storedWeightUnit, WeightUnit.pound);
  });

  testWidgets('a stored pound unit applies on launch', (tester) async {
    app.storedWeightUnit = WeightUnit.pound;
    await app.pump(tester, location: AppRoutes.allWeightHistory);
    expect(find.text('9.921 lb'), findsOneWidget);
  });
}
