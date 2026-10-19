double? parseWeight(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));

bool hasValidWeightPrecision(String input) =>
    RegExp(r'^\+?(?:\d+(?:[.,]\d{0,3})?|[.,]\d{1,3})$').hasMatch(input.trim());

double normalizeWeight(double weight) =>
    double.parse(weight.toStringAsFixed(3));

String formatWeight(double weight) =>
    normalizeWeight(weight).toString().replaceFirst(RegExp(r'\.0$'), '');
