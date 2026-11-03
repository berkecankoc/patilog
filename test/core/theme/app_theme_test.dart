import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petlytics/core/theme/app_colors.dart';
import 'package:petlytics/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('enabled reminder switches use a light thumb in the light theme', () {
    final light = AppTheme.light;
    final dark = AppTheme.dark;
    final selected = {WidgetState.selected};
    final lightThumb = light.switchTheme.thumbColor?.resolve(selected);
    final darkThumb = dark.switchTheme.thumbColor?.resolve(selected);
    expect(lightThumb, light.colorScheme.surface);
    expect(darkThumb, dark.colorScheme.onPrimary);
    expect(lightThumb, isNot(darkThumb));
    expect(
      contrast(lightThumb!, light.colorScheme.primary),
      greaterThanOrEqualTo(3),
    );
    expect(light.switchTheme.thumbColor?.resolve({}), isNull);
    expect(
      light.switchTheme.thumbColor?.resolve({
        WidgetState.selected,
        WidgetState.disabled,
      }),
      isNull,
    );
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test(
      '${theme.brightness.name} brand components and tested color pairs match the theme',
      () {
        final scheme = theme.colorScheme;
        final colors = theme.extension<AppColors>()!;
        expect(scheme.primary, AppColors.brandPrimary);
        expect(colors.primary, AppColors.brandPrimary);
        expect(scheme.onPrimary, colors.onPrimary);
        expect(theme.scaffoldBackgroundColor, colors.background);
        final textPairs = [
          (scheme.primary, scheme.onPrimary),
          (scheme.primaryContainer, scheme.onPrimaryContainer),
          (colors.success, colors.onSuccess),
          (colors.warning, colors.onWarning),
          (colors.danger, colors.onDanger),
          for (final surface in [
            colors.background,
            scheme.surface,
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
          ]) ...[
            (scheme.onSurface, surface),
            (scheme.onSurfaceVariant, surface),
            (colors.actionForeground, surface),
            (scheme.error, surface),
          ],
        ];
        for (final (foreground, background) in textPairs) {
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$foreground / $background',
          );
        }
        for (final surface in [
          colors.background,
          scheme.surface,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ]) {
          expect(contrast(scheme.outline, surface), greaterThanOrEqualTo(3));
        }
        final buttonStyle = theme.elevatedButtonTheme.style!;
        expect(buttonStyle.foregroundColor!.resolve({}), scheme.onPrimary);
        expect(buttonStyle.backgroundColor!.resolve({}), scheme.primary);
        expect(
          theme.floatingActionButtonTheme.backgroundColor,
          AppColors.brandPrimary,
        );
        expect(
          theme.floatingActionButtonTheme.foregroundColor,
          colors.onPrimary,
        );
        expect(theme.cardTheme.color, colors.surface);
        final input = theme.inputDecorationTheme;
        final focusedBorder = input.focusedBorder! as OutlineInputBorder;
        expect(focusedBorder.borderSide.color, AppColors.brandPrimary);
        expect(
          contrast(focusedBorder.borderSide.color, input.fillColor!),
          greaterThanOrEqualTo(3),
        );
        expect(theme.textSelectionTheme.cursorColor, AppColors.brandPrimary);
        expect(
          theme.textButtonTheme.style!.foregroundColor!.resolve({}),
          colors.actionForeground,
        );
        expect(
          theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
          colors.actionForeground,
        );
        expect(
          WidgetStateProperty.resolveAs(input.floatingLabelStyle!, {
            WidgetState.focused,
          }).color,
          focusedBorder.borderSide.color,
        );
        expect(
          WidgetStateProperty.resolveAs(input.floatingLabelStyle!, {
            WidgetState.focused,
            WidgetState.error,
          }).color,
          colors.danger,
        );
      },
    );
  }
}
