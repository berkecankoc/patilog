import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/widgets/app_form_scroll_view.dart';
import 'package:petlytics/core/widgets/app_multi_step_form.dart';

// Ahem's fixed-width letters can consume the entire keyboard-open viewport.
// Use the SDK's bundled app font when checking large-text form geometry.
Future<void> loadFormTestFont() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final bytes = await File(
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  ).readAsBytes();
  await (FontLoader(
    'Roboto',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

Future<void> reviewForm(WidgetTester tester) async {
  final next = find.widgetWithText(ElevatedButton, 'Continue');
  final done = find.widgetWithText(ElevatedButton, 'Done');
  if (next.evaluate().isNotEmpty || done.evaluate().isNotEmpty) {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(next.evaluate().isNotEmpty ? next : done);
    await tester.pumpAndSettle();
  }
}

Future<void> editForm(WidgetTester tester) async {
  if (find.byType(AppMultiStepForm).evaluate().isNotEmpty &&
      find.text('Step 2 of 2 · Review').evaluate().isNotEmpty) {
    final edit = find.widgetWithText(TextButton, 'Edit').first;
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
  }
}

Future<void> enterFormText(
  WidgetTester tester,
  Finder field,
  String value,
) async {
  await revealFormField(tester, field);
  await tester.enterText(field, value);
}

Future<void> tapFormControl(WidgetTester tester, Finder field) async {
  await revealFormField(tester, field);
  await tester.tap(field);
}

// Supply a finder with skipOffstage:false so hidden stages can be identified;
// navigation and expansion still happen through the actual visible controls.
Future<void> revealFormField(WidgetTester tester, Finder field) async {
  final element = field.evaluate().first;
  if (element.widget is MenuItemButton) {
    // Scroll the popup itself; scrolling its logical form ancestor closes it.
    final popup = find
        .ancestor(of: field, matching: find.byType(SingleChildScrollView))
        .first;
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: popup, matching: find.byType(Scrollable)).first,
        )
        .position;
    await position.ensureVisible(element.renderObject!, alignment: 0.5);
    await tester.pumpAndSettle();
    expect(field.hitTestable(), findsOneWidget);
    return;
  }
  int? step;
  String? optionalSection;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is AppFormOptionalSection) optionalSection ??= widget.title;
    if (widget is AppFormScrollView && widget.key is ValueKey<int>) {
      step = (widget.key! as ValueKey<int>).value;
      return false;
    }
    return true;
  });
  if (step == 0) {
    await editForm(tester);
  } else if (step == 1) {
    await reviewForm(tester);
  }
  if (optionalSection != null &&
      find.byWidget(element.widget).evaluate().isEmpty) {
    final header = find.text(optionalSection!);
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    final viewport = find
        .ancestor(of: header, matching: find.byType(SingleChildScrollView))
        .first;
    final visibleHeader = tester
        .getRect(header)
        .intersect(tester.getRect(viewport));
    expect(visibleHeader.isEmpty, isFalse);
    await tester.tapAt(visibleHeader.center);
    await tester.pumpAndSettle();
  }
  final alreadyFocused = find
      .descendant(of: field, matching: find.byType(EditableText))
      .evaluate()
      .any((element) => (element.widget as EditableText).focusNode.hasFocus);
  if (!alreadyFocused &&
      (step == null || field.hitTestable().evaluate().isEmpty)) {
    await tester.ensureVisible(field);
  }
  await tester.pumpAndSettle();
}

Future<Rect> checkFormError(WidgetTester tester, String message) async {
  final text = find.text(message);
  expect(text, findsOneWidget);
  final scroll = find
      .ancestor(of: text, matching: find.byType(SingleChildScrollView))
      .first;
  final bounds = tester.getRect(scroll);
  expect(bounds.height, greaterThan(0));
  expect(bounds.overlaps(tester.getRect(text)), isTrue);
  final position = tester
      .state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
      )
      .position;
  if (position.maxScrollExtent > 0) {
    await tester.dragFrom(bounds.center, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
  }
  return bounds;
}

Future<void> submitForm(WidgetTester tester, {bool settle = true}) async {
  await reviewForm(tester);
  if (find.widgetWithText(ElevatedButton, 'Continue').evaluate().isNotEmpty ||
      find.widgetWithText(ElevatedButton, 'Done').evaluate().isNotEmpty) {
    return;
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ElevatedButton));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> leaveForm(WidgetTester tester, {bool systemBack = false}) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    if (find.byType(AppMultiStepForm).evaluate().isEmpty ||
        find.text('Discard changes?').evaluate().isNotEmpty) {
      return;
    }
    if (systemBack) {
      await tester.binding.handlePopRoute();
    } else {
      await tester.tap(find.byType(BackButton));
    }
    await tester.pumpAndSettle();
  }
}
