import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/l10n/app_locale.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/features/vet_visit/presentation/utils/vet_visit_cost.dart';

void main() {
  test('parses decimal inputs exactly without floating point arithmetic', () {
    for (final (input, expected) in [
      ('0', 0),
      ('0,01', 1),
      ('0.10', 10),
      ('12', 1200),
      (' 1250,5 ', 125050),
      ('1250.50', 125050),
      ('92233720368547758.07', 9223372036854775807),
    ]) {
      expect(parseVetVisitCost(input), expected, reason: input);
      for (final locale in appSupportedLocales) {
        expect(parseVetVisitCost(localizedAmount(expected, locale)), expected);
      }
    }
  });

  test(
    'rejects invalid, negative, fractional-cent and overflowing amounts',
    () {
      for (final value in [
        '',
        '-1',
        'NaN',
        'Infinity',
        '1.234',
        '1,234',
        '1,2.3',
        '1.',
        '.5',
        '1e3',
        '92233720368547758.08',
      ]) {
        expect(parseVetVisitCost(value), isNull, reason: value);
      }
    },
  );
}
