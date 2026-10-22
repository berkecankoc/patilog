import 'package:flutter/services.dart';

class DoseTimeInputFormatter extends TextInputFormatter {
  const DoseTimeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) return oldValue;
    final deletingSeparator =
        oldValue.text.endsWith(':') &&
        newValue.text == oldValue.text.substring(0, oldValue.text.length - 1);
    final showSeparator = digits.length >= 2 && !deletingSeparator;
    final insertedSeparator =
        showSeparator && digits.length == 2 && !newValue.text.contains(':');
    final text = showSeparator
        ? '${digits.substring(0, 2)}:${digits.substring(2)}'
        : digits;
    int offset(int value) {
      if (value < 0) return text.length;
      final before = newValue.text.substring(
        0,
        value.clamp(0, newValue.text.length),
      );
      final count = before.replaceAll(RegExp(r'[^0-9]'), '').length;
      final afterSeparator =
          count > 2 ||
          count == 2 && (insertedSeparator || before.contains(':'));
      return showSeparator && afterSeparator ? count + 1 : count;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: offset(newValue.selection.baseOffset),
        extentOffset: offset(newValue.selection.extentOffset),
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
