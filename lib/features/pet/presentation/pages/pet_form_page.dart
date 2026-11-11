import 'package:flutter/material.dart';
import 'package:patilog/core/l10n/app_number_formats.dart';
import 'package:patilog/core/error/failure.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';
import 'package:patilog/core/router/care_record_changes.dart';
import 'package:patilog/core/router/pet_care_tab.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:patilog/core/utils/weight_utils.dart';
import 'package:patilog/core/widgets/app_gap.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/app_confirmation_dialog.dart';
import 'package:patilog/core/widgets/app_section_heading.dart';
import 'package:patilog/features/pet/domain/entities/pet.dart';
import 'package:patilog/features/pet/domain/use_cases/create_pet.dart'
    show CreatePetParams;
import 'package:patilog/features/pet/domain/use_cases/update_pet.dart'
    show UpdatePetParams;
import 'package:patilog/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:patilog/features/pet/presentation/cubit/pet_state.dart';
import 'package:patilog/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:patilog/features/pet/presentation/widgets/pet_image.dart';

class _PetImageField extends StatelessWidget {
  final String? imagePath;
  final bool isStored;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PetImageField({
    required this.imagePath,
    required this.isStored,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    Widget photoField(Widget? photo) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 120,
            child: Material(
              clipBehavior: Clip.antiAlias,
              shape: const CircleBorder(),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Semantics(
                label: photo == null
                    ? strings.addPetPhoto
                    : strings.changePetPhoto,
                button: true,
                child: InkWell(
                  onTap: onTap,
                  child:
                      photo ??
                      Center(
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                ),
              ),
            ),
          ),
          VerticalGap.sm,
          if (photo == null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(strings.addPhoto),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(
                      strings.changePhoto,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: strings.removePhoto,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return PetImage(
      imagePath: imagePath,
      isStored: isStored,
      size: 120,
      builder: photoField,
    );
  }
}

class PetFormPage extends StatefulWidget {
  final Pet? pet;
  const PetFormPage({super.key, this.pet});

  @override
  State<PetFormPage> createState() => _PetFormPageState();
}

class _PetFormPageState extends State<PetFormPage> {
  static const _nameMaxLength = 20;

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _microchipIdController = TextEditingController();

  final _imagePicker = ImagePicker();

  late PetSpecies _species;
  late PetSex _sex;
  late ReproductiveStatus _reproductiveStatus;

  DateTime? _birthDate;
  String? _pickedImagePath;
  Failure? _saveError;
  bool _allowPop = false;
  bool _confirmingDiscard = false;
  AppLocalizations get _strings => AppLocalizations.of(context);
  String? _initialWeightText;

  bool get _hasChanges {
    final pet = widget.pet;
    return _nameController.text != (pet?.name ?? '') ||
        _breedController.text != (pet?.breed ?? '') ||
        _weightController.text != _initialWeightText ||
        _microchipIdController.text != (pet?.microchipId ?? '') ||
        _species != (pet?.species ?? PetSpecies.dog) ||
        _sex != (pet?.sex ?? PetSex.male) ||
        _reproductiveStatus !=
            (pet?.reproductiveStatus ?? ReproductiveStatus.intact) ||
        !DateUtils.isSameDay(_birthDate, pet?.birthDate) ||
        _pickedImagePath != pet?.imagePath;
  }

  @override
  void initState() {
    super.initState();

    final pet = widget.pet;

    _species = pet?.species ?? PetSpecies.dog;
    _sex = pet?.sex ?? PetSex.male;
    _reproductiveStatus = pet?.reproductiveStatus ?? ReproductiveStatus.intact;

    if (pet != null) {
      _nameController.text = pet.name;
      _breedController.text = pet.breed ?? '';
      if (pet.birthDate != null) {
        _birthDate = pet.birthDate;
      }
      _microchipIdController.text = pet.microchipId ?? '';
      _pickedImagePath = pet.imagePath;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialWeightText != null) return;
    final weight = widget.pet?.weight;
    _initialWeightText = weight == null
        ? ''
        : localizedWeight(weight, Localizations.localeOf(context));
    _weightController.text = _initialWeightText!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _microchipIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_allowPop ||
        _confirmingDiscard ||
        context.read<PetCubit>().state is PetLoading) {
      return;
    }
    if (widget.pet != null && !_hasChanges) return;
    setState(() => _saveError = null);
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final species = _species;
    final sex = _sex;
    final reproductiveStatus = _reproductiveStatus;

    final breedText = _breedController.text.trim();
    final breed = breedText.isEmpty ? null : breedText;

    final birthDate = _birthDate;

    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty ? null : parseWeight(weightText)!;

    final microchipIdText = _microchipIdController.text.trim();
    final microchipId = microchipIdText.isEmpty ? null : microchipIdText;

    final sourceImagePath = _pickedImagePath;

    if (widget.pet == null) {
      final createParams = CreatePetParams(
        name: name,
        species: species,
        sex: sex,
        reproductiveStatus: reproductiveStatus,
        breed: breed,
        birthDate: birthDate,
        weight: weight,
        microchipId: microchipId,
        sourceImagePath: sourceImagePath,
      );

      context.read<PetCubit>().createPet(createParams);
    } else {
      final updateParams = UpdatePetParams(
        name: name,
        species: species,
        sex: sex,
        reproductiveStatus: reproductiveStatus,
        breed: breed,
        birthDate: birthDate,
        weight: weight,
        microchipId: microchipId,
        sourceImagePath: sourceImagePath,
      );
      context.read<PetCubit>().updatePet(widget.pet!, updateParams);
    }
  }

  Future<void> _pickImage() async {
    if (!mounted || context.read<PetCubit>().state is PetLoading) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (image == null || !mounted) return;

      setState(() {
        _pickedImagePath = image.path;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.code == 'photo_access_denied'
          ? _strings.photoAccessDenied
          : _strings.photoSelectFailed;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: _strings.retry,
              onPressed: _pickImage,
            ),
          ),
        );
    }
  }

  void _leave({bool? result}) {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    // Rebuild the pop guard before leaving after save or confirmed discard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pop(result);
    });
  }

  Future<void> _requestExit() async {
    if (_allowPop ||
        _confirmingDiscard ||
        context.read<PetCubit>().state is PetLoading) {
      return;
    }
    if (!_hasChanges) {
      _leave();
      return;
    }
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AppConfirmationDialog(
        title: AppLocalizations.of(context).discardChangesTitle,
        message: AppLocalizations.of(context).discardChangesMessage,
        cancelLabel: AppLocalizations.of(context).keepEditing,
        confirmLabel: AppLocalizations.of(context).discardChanges,
      ),
    );
    _confirmingDiscard = false;
    if (discard == true && mounted) _leave();
  }

  Widget _basicDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: _PetImageField(
          imagePath: _pickedImagePath,
          isStored: _pickedImagePath == widget.pet?.imagePath,
          onTap: _pickImage,
          onRemove: () {
            setState(() {
              _pickedImagePath = null;
            });
          },
        ),
      ),

      VerticalGap.lg,
      AppSectionHeading(title: _strings.basicDetails, icon: Icons.info_outline),
      VerticalGap.md,

      TextFormField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: _strings.petName,
          errorMaxLines: 3,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return _strings.petNameRequired;
          }
          if (value.trim().characters.length > _nameMaxLength) {
            return _strings.petNameTooLong(_nameMaxLength);
          }

          return null;
        },
      ),

      VerticalGap.md,

      Column(
        children: [
          DropdownButtonFormField<PetSpecies>(
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            initialValue: _species,
            items: PetSpecies.values.map((species) {
              return DropdownMenuItem(
                value: species,
                child: Text(species.label(_strings)),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _species = value;
              });
            },
            decoration: InputDecoration(labelText: _strings.species),
          ),

          VerticalGap.md,

          DropdownButtonFormField<PetSex>(
            isExpanded: true,
            borderRadius: BorderRadius.circular(16),
            initialValue: _sex,
            items: PetSex.values.map((sex) {
              return DropdownMenuItem(
                value: sex,
                child: Text(sex.label(_strings)),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _sex = value;
              });
            },
            decoration: InputDecoration(labelText: _strings.sex),
          ),
        ],
      ),

      VerticalGap.md,

      TextFormField(
        controller: _breedController,
        decoration: InputDecoration(labelText: _strings.breedOptional),
      ),

      VerticalGap.md,
    ],
  );

  Widget _healthDetails() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<ReproductiveStatus>(
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        initialValue: _reproductiveStatus,
        items: ReproductiveStatus.values.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(status.label(_strings)),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            _reproductiveStatus = value;
          });
        },
        decoration: InputDecoration(labelText: _strings.reproductiveStatus),
      ),

      VerticalGap.md,

      Column(
        children: [
          AppDateField(
            labelText: _strings.birthDateOptional,
            value: _birthDate,
            firstDate: DateTime(1980),
            lastDate: DateTime.now(),
            clearable: true,
            onChanged: (date) => setState(() => _birthDate = date),
          ),

          VerticalGap.md,

          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              labelText: _strings.weightOptional,
              suffixText: 'kg',
              errorMaxLines: 5,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }

              final weight = parseWeight(value);

              if (weight == null || !weight.isFinite) {
                return _strings.weightInvalid;
              }

              if (weight <= 0) {
                return _strings.weightPositive;
              }

              if (!hasValidWeightPrecision(value)) {
                return _strings.weightPrecision(3);
              }

              return null;
            },
          ),
        ],
      ),

      VerticalGap.md,

      AppSectionHeading(
        title: _strings.identification,
        icon: Icons.badge_outlined,
      ),
      VerticalGap.md,
      TextFormField(
        controller: _microchipIdController,
        decoration: InputDecoration(labelText: _strings.microchipIdOptional),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => BlocConsumer<PetCubit, PetState>(
    listener: (context, state) {
      if (state is PetCreated) {
        CareRecordChanges.maybeOf(context)?.changed(null, PetCareTab.profile);
      }
      if (state case PetCreated() || PetUpdated()) {
        _leave(result: true);
      } else if (state case PetError(:final failure)) {
        setState(() => _saveError = failure);
      }
    },
    builder: (context, state) => AppMultiStepForm(
      title: Text(widget.pet == null ? _strings.addPet : _strings.editPet),
      editing: widget.pet != null,
      isSaving: () {
        final current = context.read<PetCubit>().state;
        return current is PetLoading ||
            current is PetCreated ||
            current is PetUpdated;
      },
      allowPop: _allowPop,
      canSubmit: widget.pet == null || _hasChanges,
      submitLabel: widget.pet == null ? _strings.addPet : _strings.saveChanges,
      saveError: switch (_saveError) {
        null => null,
        ImageStorageFailure() => _strings.photoSaveFailed,
        NotFoundFailure() => _strings.petNotFound,
        _ =>
          widget.pet == null
              ? _strings.petCreateFailed
              : _strings.petUpdateFailed,
      },
      onSubmit: _submit,
      onExit: _requestExit,
      onChanged: () => setState(() {}),
      steps: [
        AppFormStep(
          title: _strings.petStep,
          builder: (_, _) => _basicDetails(),
        ),
        AppFormStep(
          title: _strings.review,
          builder: (context, edit) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _strings.reviewPet,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              VerticalGap.md,
              AppFormReviewSection(
                title: _strings.basicDetails,
                icon: Icons.info_outline,
                onEdit: () => edit(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDetailField(
                      label: _strings.petName,
                      value: _nameController.text,
                    ),
                    VerticalGap.md,
                    AppDetailField(
                      label: _strings.species,
                      value: _species.label(_strings),
                    ),
                    VerticalGap.md,
                    AppDetailField(
                      label: _strings.sex,
                      value: _sex.label(_strings),
                    ),
                    if (_breedController.text.trim().isNotEmpty) ...[
                      VerticalGap.md,
                      AppDetailField(
                        label: _strings.breed,
                        value: _breedController.text,
                      ),
                    ],
                  ],
                ),
              ),
              VerticalGap.md,
              AppFormOptionalSection(
                title: _strings.healthIdentificationOptional,
                icon: Icons.health_and_safety_outlined,
                initiallyExpanded: widget.pet != null,
                child: _healthDetails(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
