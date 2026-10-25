import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'outside touch dismisses keyboard and retains input on $platform',
      (tester) async {
        final number = TextEditingController();
        addTearDown(number.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (_, child) => AppKeyboard(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  const ColoredBox(
                    key: Key('outside'),
                    color: Colors.transparent,
                    child: SizedBox(width: double.infinity, height: 80),
                  ),
                  TextField(
                    controller: number,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Weight'),
                  ),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Name'),
                  ),
                ],
              ),
            ),
          ),
        );
        final weight = find.widgetWithText(TextField, 'Weight');
        final name = find.widgetWithText(TextField, 'Name');
        await tester.enterText(weight, '12.345');
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.tap(find.byKey(const Key('outside')));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(number.text, '12.345');
        await tester.tap(weight);
        await tester.pumpAndSettle();
        await tester.tap(name);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(of: name, matching: find.byType(EditableText)),
              )
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.tap(weight);
        await tester.pumpAndSettle();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(number.text, '12.345');
      },
    );

    testWidgets('keyboard dismissal also applies inside a modal on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (_, child) => AppKeyboard(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Record dose'),
                      TextField(
                        decoration: InputDecoration(labelText: 'Given at'),
                        keyboardType: TextInputType.number,
                      ),
                      AppHideKeyboardButton(),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final time = find.widgetWithText(TextField, 'Given at');
      await tester.enterText(time, '1234');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record dose'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Record dose'), findsOneWidget);
      await tester.tap(time);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide keyboard'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('Record dose'), findsOneWidget);
    });
  }
}
