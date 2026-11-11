import 'package:flutter_test/flutter_test.dart';
import 'package:patilog/core/l10n/app_locale.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/utils/weight_utils.dart';

void main() {
  test(
    'regional decimal separators keep weight precision and input round trips',
    () {
      expect(localizedWeight(12.345, turkishLocale), '12,345');
      expect(localizedWeight(12.345, englishLocale), '12.345');
      for (final locale in appSupportedLocales) {
        expect(localizedWeight(12, locale), '12');
        expect(parseWeight(localizedWeight(0.005, locale)), 0.005);
        expect(
          hasValidWeightPrecision(localizedWeight(12.345, locale)),
          isTrue,
        );
      }
    },
  );

  test(
    'money formatting keeps exact minor units and does not convert currency',
    () {
      expect(localizedAmount(125050, turkishLocale), '1250,50');
      expect(localizedAmount(125050, englishLocale), '1250.50');
      expect(
        localizedAmount(9223372036854775807, turkishLocale),
        '92233720368547758,07',
      );
      expect(localizedAmount(0, turkishLocale), '0,00');
    },
  );
}
