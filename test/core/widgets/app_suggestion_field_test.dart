import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_suggestion_field.dart';
import 'package:petlytics/core/widgets/app_phased_form.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';
import 'package:petlytics/core/widgets/app_form_scroll_view.dart';

void main() {
  late TextEditingController text;
  late ValueNotifier<List<String>> options;
  late ValueNotifier<bool> loading;
  late List<String> changes;

  setUp(() {
    text = TextEditingController();
    options = ValueNotifier(['Clinic A', 'Clinic B', 'Other clinic']);
    loading = ValueNotifier(false);
    changes = [];
  });
  tearDown(() {
    text.dispose();
    options.dispose();
    loading.dispose();
  });

  Future<void> pumpField(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    Brightness brightness = Brightness.light,
    double keyboard = 0,
    TextDirection direction = TextDirection.ltr,
    bool fixedActions = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: AppKeyboard(
            child: Directionality(textDirection: direction, child: child!),
          ),
        ),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Overlay.wrap(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppFormScrollView(
                      child: Column(
                        children: [
                          if (fixedActions) const SizedBox(height: 280),
                          ListenableBuilder(
                            listenable: Listenable.merge([options, loading]),
                            builder: (context, _) => AppSuggestionField(
                              label: 'Clinic (optional)',
                              controller: text,
                              suggestions: options.value,
                              loading: loading.value,
                              onChanged: changes.add,
                              validator: (value) =>
                                  value?.isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const TextField(
                            decoration: InputDecoration(
                              labelText: 'Next field',
                            ),
                          ),
                          const SizedBox(height: 600),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (fixedActions)
                AppFormNavigationActions(
                  label: 'Add visit',
                  saving: false,
                  keyboardVisible: keyboard > 0,
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final field = find.byType(TextFormField);
  final next = find.widgetWithText(TextField, 'Next field');

  testWidgets('menu padding belongs to the focused suggestion field', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(field, 'Cli');
    await tester.pumpAndSettle();
    final menu = find
        .ancestor(
          of: find.byType(MenuItemButton).first,
          matching: find.byType(Material),
        )
        .first;
    final bounds = tester.getRect(menu);
    await tester.tapAt(Offset(bounds.center.dx, bounds.top + 4));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    expect(tester.testTextInput.isVisible, isTrue);
    expect(text.text, 'Cli');
    await tester.tapAt(const Offset(380, 500));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(text.text, 'Cli');
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: next, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'touch scroll moves suggestions without closing them on $platform',
      (tester) async {
        options.value = List.generate(
          5,
          (i) => 'Clinic $i ${'long name ' * 5}',
        );
        await pumpField(tester, scale: 2, keyboard: 280, fixedActions: true);
        await tester.enterText(field, 'Clinic');
        await tester.pumpAndSettle();
        final popup = find
            .ancestor(
              of: find.byType(MenuItemButton).first,
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        final popupPosition = tester
            .state<ScrollableState>(
              find
                  .descendant(of: popup, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final form = find
            .ancestor(of: field, matching: find.byType(SingleChildScrollView))
            .first;
        final formPosition = tester
            .state<ScrollableState>(
              find
                  .descendant(of: form, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final formOffset = formPosition.pixels;
        final bounds = tester.getRect(popup);
        await tester.dragFrom(bounds.center, const Offset(0, -80));
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(5));
        expect(popupPosition.pixels, greaterThan(0));
        expect(formPosition.pixels, formOffset);
        expect(tester.testTextInput.isVisible, isTrue);
        final downOffset = popupPosition.pixels;
        await tester.dragFrom(bounds.center, const Offset(0, 60));
        await tester.pumpAndSettle();
        expect(popupPosition.pixels, lessThan(downOffset));
        expect(find.byType(MenuItemButton), findsNWidgets(5));
        final last = find.byType(MenuItemButton).last;
        for (
          var attempt = 0;
          attempt < 5 && last.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.dragFrom(bounds.center, const Offset(0, -120));
          await tester.pumpAndSettle();
        }
        expect(last.hitTestable(), findsOneWidget);
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(text.text, options.value.last);
        expect(
          changes.where((value) => value == options.value.last),
          hasLength(1),
        );
        expect(find.byType(MenuItemButton), findsNothing);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets('suggestions never cover fixed form actions above the keyboard', (
    tester,
  ) async {
    await pumpField(tester, keyboard: 280, fixedActions: true);
    await tester.enterText(field, 'Cli');
    await tester.pumpAndSettle();
    final menu = find
        .ancestor(
          of: find.byType(MenuItemButton).first,
          matching: find.byType(Material),
        )
        .first;
    final actions = find.byKey(const ValueKey('phased-form-actions'));
    expect(
      tester.getRect(menu).bottom,
      lessThanOrEqualTo(tester.getRect(actions).top),
    );
    expect(find.text('Add visit').hitTestable(), findsOneWidget);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Clinic A'));
    await tester.pumpAndSettle();
    expect(text.text, 'Clinic A');
  });

  testWidgets(
    'suggestions and loading do not move neighboring fields or steal typing focus',
    (tester) async {
      await pumpField(tester);
      final bounds = tester.getRect(next);
      final height = tester.getSize(field).height;
      await tester.enterText(field, 'Cli');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      expect(tester.getRect(next), bounds);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      loading.value = true;
      await tester.pump();
      expect(tester.getSize(field).height, height);
      expect(tester.getRect(next), bounds);
      loading.value = false;
      await tester.enterText(field, 'No match');
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(tester.getRect(next), bounds);
    },
  );

  testWidgets(
    'late options update an already focused field and selection notifies once',
    (tester) async {
      options.value = [];
      await pumpField(tester);
      await tester.enterText(field, 'Cli');
      await tester.pumpAndSettle();
      options.value = ['Clinic B'];
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(MenuItemButton, 'Clinic B').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(MenuItemButton, 'Clinic B'));
      await tester.pumpAndSettle();
      expect(text.text, 'Clinic B');
      expect(changes, ['Cli', 'Clinic B']);
      expect(find.byType(MenuItemButton), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isFalse,
      );
    },
  );

  testWidgets(
    'escape and outside taps dismiss the menu without discarding input',
    (tester) async {
      await pumpField(tester);
      await tester.enterText(field, 'Cli');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(text.text, 'Cli');
      await tester.enterText(field, 'Clin');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(380, 500));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(text.text, 'Clin');
    },
  );

  testWidgets('dismissed suggestions stay closed when options finish loading', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(field, 'Cli');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    options.value = ['Clinic C'];
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.enterText(field, 'Clin');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Clinic C'), findsOneWidget);
  });

  testWidgets('keyboard can reach and select an offered name', (tester) async {
    await pumpField(tester);
    await tester.enterText(field, 'Cli');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(text.text, 'Clinic A');
    expect(find.byType(MenuItemButton), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final size in [const Size(320, 568), const Size(640, 320)]) {
      testWidgets(
        'suggestions stay above fixed actions at $size in $brightness with large text',
        (tester) async {
          await pumpField(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
            keyboard: size.width == 320 ? 240 : 100,
            fixedActions: true,
          );
          await tester.enterText(field, 'Cli');
          await tester.pumpAndSettle();
          final menu = find
              .ancestor(
                of: find.byType(MenuItemButton).first,
                matching: find.byType(Material),
              )
              .first;
          final actions = find.byKey(const ValueKey('phased-form-actions'));
          expect(
            tester.getRect(menu).bottom,
            lessThanOrEqualTo(tester.getRect(actions).top),
          );
          expect(tester.getRect(menu).top, greaterThanOrEqualTo(0));
          expect(find.text('Add visit').hitTestable(), findsOneWidget);
          await tester.tap(find.byType(MenuItemButton).first);
          await tester.pumpAndSettle();
          expect(text.text, 'Clinic A');
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'menu fits the field and keyboard at $size in $brightness with large text',
        (tester) async {
          final keyboard = size.width == 320 ? 240.0 : 0.0;
          options.value = List.generate(
            10,
            (i) => 'Clinic $i ${'long name ' * 8}',
          );
          await pumpField(
            tester,
            size: size,
            scale: 2,
            brightness: brightness,
            keyboard: keyboard,
          );
          await tester.enterText(field, 'Clinic');
          await tester.pumpAndSettle();
          final menu = find
              .ancestor(
                of: find.byType(MenuItemButton).first,
                matching: find.byType(Material),
              )
              .first;
          final menuBounds = tester.getRect(menu);
          final fieldBounds = tester.getRect(field);
          expect(menuBounds.left, closeTo(fieldBounds.left, 0.1));
          expect(menuBounds.width, closeTo(fieldBounds.width, 0.1));
          expect(menuBounds.bottom, lessThanOrEqualTo(size.height - keyboard));
          expect(find.byType(MenuItemButton), findsNWidgets(5));
          final option = find.byType(MenuItemButton).first;
          expect(option.hitTestable(), findsOneWidget);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(text.text, options.value.first);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('RTL suggestions align to the field and disappear on scroll', (
    tester,
  ) async {
    await pumpField(tester, direction: TextDirection.rtl);
    await tester.enterText(field, 'Cli');
    await tester.pumpAndSettle();
    final menu = find
        .ancestor(
          of: find.byType(MenuItemButton).first,
          matching: find.byType(Material),
        )
        .first;
    expect(
      tester.getRect(menu).right,
      closeTo(tester.getRect(field).right, 0.1),
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(text.text, 'Cli');
  });
}
