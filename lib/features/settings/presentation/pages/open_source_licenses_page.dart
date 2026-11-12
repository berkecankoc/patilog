import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

/// Shows Patilog's license and the notices of bundled packages, which the
/// BSD, MIT and Apache licenses require in binary distributions.
class OpenSourceLicensesPage extends StatelessWidget {
  const OpenSourceLicensesPage({super.key});

  @override
  Widget build(BuildContext context) => LicensePage(
    applicationName: 'Patilog',
    applicationLegalese: AppLocalizations.of(context).appLegalese,
  );
}
