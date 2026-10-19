import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/utils/weight_utils.dart';

void main() {
  test('parses decimal separators without treating them as grouping', () {
    expect(parseWeight(' 4,125 '), 4.125);
    expect(parseWeight('0.001'), 0.001);
    expect(parseWeight('1,2.3'), isNull);
  });

  test('accepts plain decimal weights with at most three decimal places', () {
    for (final value in ['4', '4.', '.125', '4,25', '0.001', ' 4.125 ']) {
      expect(hasValidWeightPrecision(value), isTrue, reason: value);
    }
    for (final value in ['4.1256', '4,1256', '0.0001', '1e-4', '1e3']) {
      expect(hasValidWeightPrecision(value), isFalse, reason: value);
    }
  });

  test('formats gram precision without trailing zeros', () {
    expect(formatWeight(4), '4');
    expect(formatWeight(4.250), '4.25');
    expect(formatWeight(0.001), '0.001');
    expect(formatWeight(4.1256), '4.126');
    expect(formatWeight(0.1 + 0.2), '0.3');
    expect(formatWeight(1e30), '1e+30');
  });
}
