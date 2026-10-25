import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';

void main() {
  testWidgets(
    'rapid field switching with selection menus keeps copy working on iOS',
    (tester) async {
      final first = TextEditingController(text: 'First');
      final second = TextEditingController(text: 'Second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.contextMenu,
        (_) async => null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard != null};
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.contextMenu,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(supportsShowingSystemContextMenu: true),
            child: AppKeyboard(child: child!),
          ),
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: first),
                const SizedBox(height: 160),
                TextField(controller: second),
              ],
            ),
          ),
        ),
      );
      final fields = find.byType(EditableText);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      final firstEditor = tester.state<EditableTextState>(fields.first);
      firstEditor.selectAll(SelectionChangedCause.longPress);
      firstEditor.showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).last);
      final secondEditor = tester.state<EditableTextState>(fields.last);
      secondEditor.selectAll(SelectionChangedCause.longPress);
      secondEditor.showToolbar();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(secondEditor.widget.focusNode.hasFocus, isTrue);
      expect(find.byType(SystemContextMenu), findsNothing);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, 'Second');
      expect(first.text, 'First');
      expect(second.text, 'Second');
      clipboard = 'Updated';
      secondEditor.selectAll(SelectionChangedCause.toolbar);
      secondEditor.showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(second.text, 'Updated');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
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
