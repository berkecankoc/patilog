import 'package:flutter/material.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:patilog/core/widgets/app_gap.dart';

class AppRelatedClinicalDetails extends StatelessWidget {
  final String? clinicName;
  final String? veterinarianName;
  final String? parentClinicName;
  final String? parentVeterinarianName;

  const AppRelatedClinicalDetails({
    super.key,
    this.clinicName,
    this.veterinarianName,
    this.parentClinicName,
    this.parentVeterinarianName,
  });

  static bool _differs(String? value, String? parent) {
    String clean(String? text) =>
        (text ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final normalized = clean(value);
    return normalized.isNotEmpty && normalized != clean(parent);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_differs(clinicName, parentClinicName)) ...[
        VerticalGap.sm,
        AppDetailField(
          label: AppLocalizations.of(context).clinic,
          value: clinicName,
        ),
      ],
      if (_differs(veterinarianName, parentVeterinarianName)) ...[
        VerticalGap.sm,
        AppDetailField(
          label: AppLocalizations.of(context).veterinarian,
          value: veterinarianName,
        ),
      ],
    ],
  );
}
