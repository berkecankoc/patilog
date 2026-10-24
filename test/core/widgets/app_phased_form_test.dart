import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_phased_form.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';

void main() {
  late TextEditingController name;
  late TextEditingController note;
  var saves = 0;
  var exits = 0;
  var saving = false;
  String? error;
  Widget? status;
  late StateSetter rebuild;

  setUp(() {
    name = TextEditingController();
    note = TextEditingController();
    saves = 0;
    exits = 0;
    saving = false;
    error = null;
    status = null;
  });
  tearDown(() {
    name.dispose();
    note.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool editing = false,
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
    String submitLabel = 'Save changes',
    String sectionTitle = 'Details',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: keyboard),
                padding: EdgeInsets.only(bottom: keyboard > 0 ? 0 : 34),
                viewPadding: const EdgeInsets.only(bottom: 34),
              ),
              child: AppPhasedForm(
                title: const Text('Test form'),
                editing: editing,
                isSaving: () => saving,
                allowPop: false,
                canSubmit: true,
                submitLabel: submitLabel,
                saveError: error,
                status: status,
                onSubmit: () => saves++,
                onExit: () => exits++,
                onChanged: () => setState(() {}),
                steps: [
                  AppFormStep(
                    title: 'Details',
                    builder: (_, _) => TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value!.trim().isEmpty ? 'Enter a name' : null,
                    ),
                  ),
                  AppFormStep(
                    title: 'Review',
                    builder: (_, edit) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppFormReviewSection(
                          title: sectionTitle,
                          icon: Icons.info_outline,
                          onEdit: () => edit(0),
                          child: Text(name.text),
                        ),
                        const SizedBox(height: 16),
                        AppFormOptionalSection(
                          title: 'Notes (optional)',
                          icon: Icons.notes_outlined,
                          child: TextFormField(
                            controller: note,
                            decoration: const InputDecoration(
                              labelText: 'Note',
                            ),
                            validator: (value) =>
                                value!.length > 3 ? 'Keep it short' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ElevatedButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets('creation validates its step and persists only from Review', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'Continue');
    expect(find.text('Enter a name'), findsOneWidget);
    expect(saves, 0);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Milo');
    await tap(tester, 'Continue');
    expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
    expect(saves, 0);
    await tap(tester, 'Save changes');
    expect(saves, 1);
  });

  testWidgets('edit starts at Review and section editing has one Done action', (
    tester,
  ) async {
    name.text = 'Milo';
    await pump(tester, editing: true);
    expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Back'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Done'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Buddy');
    await tap(tester, 'Done');
    expect(find.text('Buddy'), findsOneWidget);
    expect(saves, 0);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(exits, 1);
  });

  testWidgets('large review headings keep Edit accessible on narrow screens', (
    tester,
  ) async {
    name.text = 'Milo';
    await pump(
      tester,
      editing: true,
      size: const Size(320, 568),
      scale: 2,
      sectionTitle: 'Measurement',
    );
    final edit = find.widgetWithText(TextButton, 'Edit');
    expect(
      tester.getTopLeft(edit).dy,
      greaterThanOrEqualTo(tester.getBottomRight(find.text('Measurement')).dy),
    );
    expect(edit.hitTestable(), findsOneWidget);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2 · Details'), findsOneWidget);
    expect(name.text, 'Milo');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system and app bar Back retrace stages without losing the draft',
    (tester) async {
      await pump(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Milo',
      );
      await tap(tester, 'Continue');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2 · Details'), findsOneWidget);
      expect(name.text, 'Milo');
      expect(exits, 0);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(exits, 1);
    },
  );

  testWidgets(
    'final validation reveals invalid hidden stages and collapsed fields',
    (tester) async {
      name.text = 'Milo';
      await pump(tester, editing: true);
      name.text = '';
      await tester.pumpAndSettle();
      await tap(tester, 'Save changes');
      expect(find.text('Enter a name').hitTestable(), findsOneWidget);
      expect(saves, 0);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Buddy',
      );
      await tap(tester, 'Done');
      note.text = 'Too long';
      await tester.pumpAndSettle();
      await tap(tester, 'Save changes');
      expect(find.text('Keep it short').hitTestable(), findsOneWidget);
      expect(saves, 0);
    },
  );

  testWidgets('pending saves block stage navigation, exit and resubmission', (
    tester,
  ) async {
    name.text = 'Milo';
    await pump(tester, editing: true);
    rebuild(() => saving = true);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 0);
    expect(saves, 0);
    expect(
      tester.widget<BackButton>(find.byType(BackButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('status changes keep the current step, draft and fixed actions', (
    tester,
  ) async {
    name.text = 'Milo';
    status = AppErrorFeedback(
      message: 'History unavailable',
      retryLabel: 'Retry history',
      onRetry: () => rebuild(() {
        status = const LinearProgressIndicator(
          semanticsLabel: 'Checking history',
        );
      }),
    );
    await pump(tester, editing: true, size: const Size(320, 568), scale: 2);
    final edit = find.widgetWithText(TextButton, 'Edit');
    await tester.ensureVisible(edit);
    await tester.pumpAndSettle();
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Buddy');
    await tester.tap(find.text('Retry history'));
    await tester.pump();
    expect(find.text('Step 1 of 2 · Details'), findsOneWidget);
    expect(name.text, 'Buddy');
    expect(find.text('Done').hitTestable(), findsOneWidget);
    rebuild(() => status = null);
    await tester.pumpAndSettle();
    await tap(tester, 'Done');
    expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
    expect(find.text('Buddy'), findsOneWidget);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving guard applies before the next rendered frame', (
    tester,
  ) async {
    name.text = 'Milo';
    await pump(tester);
    await tap(tester, 'Continue');
    final save = tester
        .widget<ElevatedButton>(find.byType(ElevatedButton))
        .onPressed!;
    save();
    saving = true;
    tester.widget<BackButton>(find.byType(BackButton)).onPressed!();
    save();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
    expect(saves, 1);
    expect(exits, 0);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'long creation action clears keyboard and keeps app bar Back at $size in $brightness',
        (tester) async {
          name.text = 'Milo';
          final inset = size.height > 400 ? 220.0 : 100.0;
          await pump(
            tester,
            brightness: brightness,
            size: size,
            scale: 2,
            keyboard: inset,
            submitLabel: 'Add vaccination',
          );
          await tap(tester, 'Continue');
          expect(find.text('Step 2 of 2 · Review'), findsOneWidget);
          expect(find.widgetWithText(TextButton, 'Back'), findsNothing);
          final button = find.widgetWithText(ElevatedButton, 'Add vaccination');
          expect(button.hitTestable(), findsOneWidget);
          expect(
            tester.getBottomRight(button).dy,
            lessThanOrEqualTo(size.height - inset),
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Step 1 of 2 · Details'), findsOneWidget);
          expect(name.text, 'Milo');
          expect(exits, 0);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'fixed actions and error remain visible at $size in $brightness',
        (tester) async {
          name.text = 'Milo';
          error = 'Save failed';
          final inset = size.height > 400 ? 220.0 : 100.0;
          await pump(
            tester,
            editing: true,
            brightness: brightness,
            size: size,
            scale: 2,
            keyboard: inset,
          );
          expect(find.text('Save failed').hitTestable(), findsOneWidget);
          expect(find.text('Retry'), findsNothing);
          expect(find.text('Save changes').hitTestable(), findsOneWidget);
          expect(
            tester.getBottomRight(find.byType(ElevatedButton)).dy,
            lessThanOrEqualTo(size.height - inset),
          );
          expect(find.byType(StretchingOverscrollIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
