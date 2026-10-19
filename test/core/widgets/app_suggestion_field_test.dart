import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_theme.dart';
import 'package:petlytics/core/widgets/app_suggestion_field.dart';

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
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
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
                    decoration: InputDecoration(labelText: 'Next field'),
                  ),
                  const SizedBox(height: 600),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final field = find.byType(TextFormField);
  final next = find.widgetWithText(TextField, 'Next field');

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
