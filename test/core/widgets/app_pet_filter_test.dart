import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/theme/app_theme.dart';
import 'package:patilog/core/widgets/app_pet_filter.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import '../../helpers/multi_step_form_helpers.dart';

const pets = [
  Pet(
    id: 'cat',
    name: 'Milo',
    species: PetSpecies.cat,
    sex: PetSex.unknown,
    reproductiveStatus: ReproductiveStatus.unknown,
  ),
  Pet(
    id: 'dog',
    name: 'Milo',
    species: PetSpecies.dog,
    sex: PetSex.unknown,
    reproductiveStatus: ReproductiveStatus.unknown,
  ),
  Pet(
    id: 'bird',
    name: 'Pip',
    species: PetSpecies.bird,
    sex: PetSex.unknown,
    reproductiveStatus: ReproductiveStatus.unknown,
  ),
  Pet(
    id: 'other',
    name: 'Luna',
    species: PetSpecies.other,
    sex: PetSex.unknown,
    reproductiveStatus: ReproductiveStatus.unknown,
  ),
];

Widget app(
  Widget child, {
  Locale locale = const Locale('en', 'US'),
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.light,
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: Center(child: SizedBox(width: 272, child: child)),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
);

void main() {
  setUpAll(loadFormTestFont);
  for (final tr in [false, true]) {
    testWidgets(
      'pet names and species distinguish duplicate names in ${tr ? 'TR' : 'EN'}',
      (tester) async {
        String? selected = 'cat';
        final changes = <String?>[];
        await tester.pumpWidget(
          app(
            StatefulBuilder(
              builder: (context, setState) => AppPetFilter(
                pets: pets,
                selectedPetId: selected,
                onChanged: (id) {
                  changes.add(id);
                  setState(() => selected = id);
                },
              ),
            ),
            locale: Locale(tr ? 'tr' : 'en', tr ? 'TR' : 'US'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        for (final label
            in tr
                ? ['Milo · Kedi', 'Milo · Köpek', 'Pip · Kuş', 'Luna · Diğer']
                : ['Milo · Cat', 'Milo · Dog', 'Pip · Bird', 'Luna · Other']) {
          expect(find.text(label), findsWidgets);
        }
        await tester.tap(find.text(tr ? 'Milo · Köpek' : 'Milo · Dog').last);
        await tester.pumpAndSettle();
        expect(selected, 'dog');
        expect(changes, ['dog']);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        final strings = AppLocalizations.of(
          tester.element(find.byType(AppPetFilter)),
        );
        await tester.tap(find.text(strings.allPets).last);
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(changes, ['dog', null]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a removed selection falls back to all pets and disabled input stays inert',
    (tester) async {
      await tester.pumpWidget(
        app(AppPetFilter(pets: pets, selectedPetId: 'cat', onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          AppPetFilter(
            pets: pets.skip(1).toList(),
            selectedPetId: 'cat',
            onChanged: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(field.initialValue, '');
      expect(field.onChanged, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Milo · Dog').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('long selected labels stay on one line at large text', (
    tester,
  ) async {
    final pet = pets.first.copyWith(name: 'A long companion');
    await tester.pumpWidget(
      app(
        AppPetFilter(pets: [pet], selectedPetId: pet.id, onChanged: (_) {}),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('${pet.name} · Cat');
    final context = tester.element(label);
    final painter = TextPainter(
      text: TextSpan(
        text: '${pet.name} · Cat',
        style: DefaultTextStyle.of(context).style,
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    expect(tester.getSize(label).height, closeTo(painter.height, 0.1));
    expect(
      tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
      isTrue,
    );
    painter.dispose();
    expect(tester.takeException(), isNull);
  });
}
