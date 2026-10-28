import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/utils/time_input_formatter.dart';

void main() {
  const formatter = TimeInputFormatter();
  TextEditingValue value(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );

  test('numeric typing inserts the separator and preserves the caret', () {
    var previous = value('');
    for (final (input, expected) in [
      ('0', '0'),
      ('09', '09:'),
      ('09:3', '09:3'),
      ('09:30', '09:30'),
    ]) {
      previous = formatter.formatEditUpdate(previous, value(input));
      expect(previous.text, expected);
      expect(previous.selection.extentOffset, expected.length);
    }
  });

  test(
    'backspace can remove an automatic separator without trapping the caret',
    () {
      final noMinutes = formatter.formatEditUpdate(value('09:3'), value('09:'));
      expect(noMinutes.text, '09:');
      expect(noMinutes.selection.extentOffset, 3);
      final noSeparator = formatter.formatEditUpdate(noMinutes, value('09'));
      expect(noSeparator.text, '09');
      expect(noSeparator.selection.extentOffset, 2);
      final oneDigit = formatter.formatEditUpdate(noSeparator, value('0'));
      expect(oneDigit.text, '0');
      expect(oneDigit.selection.extentOffset, 1);
      final hours = formatter.formatEditUpdate(oneDigit, value('08'));
      expect(hours.text, '08:');
      expect(hours.selection.extentOffset, 3);
    },
  );

  test('paste, replacement and deletion keep editable numeric time', () {
    expect(formatter.formatEditUpdate(value(''), value('2359')).text, '23:59');
    expect(formatter.formatEditUpdate(value(''), value('08:45')).text, '08:45');
    final replaced = formatter.formatEditUpdate(
      value('08:45', 2),
      value('09:45', 2),
    );
    expect(replaced.text, '09:45');
    expect(replaced.selection.extentOffset, 2);
    final backspace = formatter.formatEditUpdate(value('09:30'), value('09:3'));
    expect(backspace.text, '09:3');
    expect(backspace.selection.extentOffset, 4);
    final separatorBackspace = formatter.formatEditUpdate(
      value('09:30', 3),
      value('0930', 2),
    );
    expect(separatorBackspace.text, '09:30');
    expect(separatorBackspace.selection.extentOffset, 2);
    expect(formatter.formatEditUpdate(value('09:30'), value('')).text, '');
  });

  test('limits input to four digits without resetting valid text', () {
    final previous = value('12:34');
    expect(formatter.formatEditUpdate(previous, value('12:345')), previous);
    expect(
      formatter.formatEditUpdate(value(''), value('abc09-30')).text,
      '09:30',
    );
  });

  test('preserves an active IME composition', () {
    const composing = TextEditingValue(
      text: '09',
      composing: TextRange(start: 0, end: 2),
    );
    expect(formatter.formatEditUpdate(value(''), composing), composing);
  });
}
