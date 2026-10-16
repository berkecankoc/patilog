/// All supported currencies have 100 minor units per main unit.
String formatVetVisitCost(int minorUnits) =>
    '${minorUnits ~/ 100}.${(minorUnits % 100).toString().padLeft(2, '0')}';

int? parseVetVisitCost(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.replaceAll(',', '.').split('.');
  final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  return int.tryParse('${parts[0]}$fraction');
}
