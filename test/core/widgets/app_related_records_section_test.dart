import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/widgets/app_related_records_section.dart';

void main() {
  testWidgets(
    'translating a heading preserves expansion without loading again',
    (tester) async {
      final title = ValueNotifier('Linked records');
      addTearDown(title.dispose);
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: title,
              builder: (context, heading, _) => AppRelatedRecordsSection(
                key: const ValueKey(('pet', 'record')),
                title: heading,
                icon: Icons.link,
                onLoad: () => loads++,
                child: const Text('Loaded record'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Linked records'));
      await tester.pumpAndSettle();
      title.value = 'Bağlı kayıtlar';
      await tester.pumpAndSettle();
      expect(find.text('Bağlı kayıtlar'), findsOneWidget);
      expect(find.text('Loaded record').hitTestable(), findsOneWidget);
      expect(loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'plain related content stretches to the logical start in $direction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: AppRelatedRecordsSection(
                  title: 'Linked records',
                  icon: Icons.link,
                  onLoad: () {},
                  child: const Text('Short content'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Linked records'));
        await tester.pumpAndSettle();
        final card = tester.getRect(find.byType(Card));
        final content = tester.getRect(find.text('Short content'));
        expect(content.left, closeTo(card.left + 16, 0.01));
        expect(content.right, closeTo(card.right - 16, 0.01));
      },
    );
  }
  testWidgets(
    'loaded or failed child scroll does not read the expansion boolean',
    (tester) async {
      Widget page(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: AppRelatedRecordsSection(
            key: const ValueKey('record'),
            title: 'Linked records',
            icon: Icons.link,
            onLoad: () {},
            child: child,
          ),
        ),
      );
      await tester.pumpWidget(page(const Text('Loading')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Linked records'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        page(
          const SizedBox(
            height: 100,
            child: SingleChildScrollView(child: Text('Loaded')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Loaded').hitTestable(), findsOneWidget);
    },
  );
  testWidgets(
    'related expansion storage is separate from parent scroll offset',
    (tester) async {
      final bucket = PageStorageBucket();
      var loads = 0;
      Widget page() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: SingleChildScrollView(
              key: const PageStorageKey('parent-scroll'),
              child: Column(
                children: [
                  AppRelatedRecordsSection(
                    key: const ValueKey(('pet', 'record')),
                    title: 'Linked records',
                    icon: Icons.link,
                    onLoad: () => loads++,
                    child: const Text('Loaded records'),
                  ),
                  const SizedBox(height: 1400),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Linked records'));
      await tester.tap(find.text('Linked records'));
      await tester.pumpAndSettle();
      expect(find.text('Loaded records').hitTestable(), findsOneWidget);
      expect(loads, 1);
    },
  );
}
