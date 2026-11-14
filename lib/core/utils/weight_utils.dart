enum WeightUnit {
  kilogram('kg'),
  pound('lb');

  final String symbol;

  const WeightUnit(this.symbol);
}

const _kilogramsPerPound = 0.45359237;

double? parseWeight(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));

bool hasValidWeightPrecision(String input) =>
    RegExp(r'^\+?(?:\d+(?:[.,]\d{0,3})?|[.,]\d{1,3})$').hasMatch(input.trim());

/// Stored kilograms keep milligram precision so pound entries round-trip.
double normalizeWeight(double weight) =>
    double.parse(weight.toStringAsFixed(6));

double toKilograms(double value, WeightUnit unit) =>
    normalizeWeight(switch (unit) {
      WeightUnit.kilogram => value,
      WeightUnit.pound => value * _kilogramsPerPound,
    });

double fromKilograms(double kilograms, WeightUnit unit) => switch (unit) {
  WeightUnit.kilogram => kilograms,
  WeightUnit.pound => kilograms / _kilogramsPerPound,
};

/// Displays at most the three decimals users can enter.
String formatWeight(double weight) =>
    double.parse(weight.toStringAsFixed(3))
        .toString()
        .replaceFirst(RegExp(r'\.0$'), '');
