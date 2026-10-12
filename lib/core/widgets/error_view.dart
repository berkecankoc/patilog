import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_colors.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.colors.danger),

            VerticalGap.md,

            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            VerticalGap.sm,

            Text(message, textAlign: TextAlign.center),

            VerticalGap.lg,

            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
