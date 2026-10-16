import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/core/widgets/app_date_field.dart';
import 'package:petlytics/core/widgets/app_confirmation_dialog.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart'
    show CreatePetParams;
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart'
    show UpdatePetParams;
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';
import 'package:petlytics/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_image.dart';

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
                label: photo == null ? 'Add pet photo' : 'Change pet photo',
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
              child: const Text('Add photo'),
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
                    child: const Text(
                      'Change photo',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove photo',
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
  final _formKey = GlobalKey<FormState>();

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
  String? _saveError;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  bool get _hasChanges {
    final pet = widget.pet;
    return _nameController.text != (pet?.name ?? '') ||
        _breedController.text != (pet?.breed ?? '') ||
        _weightController.text != (pet?.weight?.toString() ?? '') ||
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
      if (pet.weight != null) {
        _weightController.text = pet.weight.toString();
      }
      _microchipIdController.text = pet.microchipId ?? '';
      _pickedImagePath = pet.imagePath;
    }
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
    if (context.read<PetCubit>().state is PetLoading) return;
    if (widget.pet != null && !_hasChanges) return;
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      Scrollable.ensureVisible(
        invalidFields.first.context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }

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
    final weight = weightText.isEmpty ? null : double.parse(weightText);

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
          ? 'Photo access was denied. Allow access in Settings and try again.'
          : 'Could not select a photo. Please try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(label: 'Retry', onPressed: _pickImage),
          ),
        );
    }
  }

  void _leave([bool? result]) {
    setState(() => _allowPop = true);
    // Rebuild the pop guard before leaving after save or confirmed discard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(result);
    });
  }

  Future<void> _requestExit() async {
    if (_confirmingDiscard || context.read<PetCubit>().state is PetLoading) {
      return;
    }
    if (!_hasChanges) {
      context.pop();
      return;
    }
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Discard changes?',
        message: 'Your changes have not been saved. Leave without saving?',
        cancelLabel: 'Keep editing',
        confirmLabel: 'Discard changes',
      ),
    );
    _confirmingDiscard = false;
    if (discard == true && mounted) _leave();
  }

  Widget _saveActions(bool saving) {
    return AppFormActions(
      label: widget.pet == null ? 'Add pet' : 'Save changes',
      saving: saving,
      fixed: widget.pet != null,
      onPressed: widget.pet != null && !_hasChanges ? null : _submit,
      feedback: _saveError == null
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                semanticsLabel: 'Could not save pet: $_saveError',
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PetCubit, PetState>(
      listener: (context, state) {
        if (state case PetCreated() || PetUpdated()) {
          _leave(true);
        }

        if (state case PetError(:final message)) {
          setState(() => _saveError = message);
        }
      },
      builder: (context, state) {
        final saving = state is PetLoading;
        return PopScope<bool>(
          canPop: !saving && (_allowPop || !_hasChanges),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !saving) _requestExit();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.pet == null ? 'Add pet' : 'Edit pet'),
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                onPressed: saving ? null : _requestExit,
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: saving,
                    child: SafeArea(
                      bottom: widget.pet == null,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Form(
                              key: _formKey,
                              onChanged: () => setState(() {}),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    widget.pet == null
                                        ? 'Meet your new companion'
                                        : 'Edit pet details',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  VerticalGap.sm,
                                  Text(
                                    widget.pet == null
                                        ? 'Start with a name and species. You can add more details whenever you’re ready.'
                                        : 'Update the information below, then save your changes.',
                                  ),
                                  VerticalGap.lg,
                                  Center(
                                    child: _PetImageField(
                                      imagePath: _pickedImagePath,
                                      isStored:
                                          _pickedImagePath ==
                                          widget.pet?.imagePath,
                                      onTap: _pickImage,
                                      onRemove: () {
                                        setState(() {
                                          _pickedImagePath = null;
                                        });
                                      },
                                    ),
                                  ),

                                  VerticalGap.lg,
                                  const AppSectionHeading(
                                    title: 'Basic details',
                                    icon: Icons.info_outline,
                                  ),
                                  VerticalGap.md,

                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Name*',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Name is required';
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
                                            child: Text(species.label),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value == null) return;

                                          setState(() {
                                            _species = value;
                                          });
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Species',
                                        ),
                                      ),

                                      VerticalGap.md,

                                      DropdownButtonFormField<PetSex>(
                                        isExpanded: true,
                                        borderRadius: BorderRadius.circular(16),
                                        initialValue: _sex,
                                        items: PetSex.values.map((sex) {
                                          return DropdownMenuItem(
                                            value: sex,
                                            child: Text(sex.label),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value == null) return;

                                          setState(() {
                                            _sex = value;
                                          });
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Sex',
                                        ),
                                      ),
                                    ],
                                  ),

                                  VerticalGap.md,

                                  TextFormField(
                                    controller: _breedController,
                                    decoration: const InputDecoration(
                                      labelText: 'Breed',
                                    ),
                                  ),

                                  VerticalGap.md,

                                  const AppSectionHeading(
                                    title: 'Health details',
                                    icon: Icons.health_and_safety_outlined,
                                  ),
                                  VerticalGap.md,
                                  DropdownButtonFormField<ReproductiveStatus>(
                                    isExpanded: true,
                                    borderRadius: BorderRadius.circular(16),
                                    initialValue: _reproductiveStatus,
                                    items: ReproductiveStatus.values.map((
                                      status,
                                    ) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Text(status.label),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == null) return;

                                      setState(() {
                                        _reproductiveStatus = value;
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Reproductive Status',
                                    ),
                                  ),

                                  VerticalGap.md,

                                  Column(
                                    children: [
                                      AppDateField(
                                        labelText: 'Birth date',
                                        value: _birthDate,
                                        firstDate: DateTime(1980),
                                        lastDate: DateTime.now(),
                                        clearable: true,
                                        onChanged: (date) =>
                                            setState(() => _birthDate = date),
                                      ),

                                      VerticalGap.md,

                                      TextFormField(
                                        controller: _weightController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Weight',
                                          suffixText: 'kg',
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return null;
                                          }

                                          final weight = double.tryParse(
                                            value.trim(),
                                          );

                                          if (weight == null ||
                                              !weight.isFinite) {
                                            return 'Enter a valid weight';
                                          }

                                          if (weight <= 0) {
                                            return 'Weight must be greater than 0';
                                          }

                                          return null;
                                        },
                                      ),
                                    ],
                                  ),

                                  VerticalGap.md,

                                  const AppSectionHeading(
                                    title: 'Identification',
                                    icon: Icons.badge_outlined,
                                  ),
                                  VerticalGap.md,
                                  TextFormField(
                                    controller: _microchipIdController,
                                    decoration: const InputDecoration(
                                      labelText: 'Microchip ID',
                                    ),
                                  ),
                                  if (widget.pet == null) ...[
                                    VerticalGap.xl,
                                    _saveActions(saving),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.pet != null) _saveActions(saving),
              ],
            ),
          ),
        );
      },
    );
  }
}
