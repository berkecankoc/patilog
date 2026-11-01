import 'package:flutter/material.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:petlytics/core/router/app_routes.dart';

class MyPetsButton extends StatelessWidget {
  final bool enabled;

  const MyPetsButton({super.key, this.enabled = true});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).myPets,
    icon: const Icon(Icons.home_outlined),
    onPressed: enabled ? () => context.go(AppRoutes.pets) : null,
  );
}
