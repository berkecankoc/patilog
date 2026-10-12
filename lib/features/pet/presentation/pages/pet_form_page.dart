import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_gap.dart';
import 'package:petlytics/features/pet/domain/entities/pet.dart';
import 'package:petlytics/features/pet/domain/use_cases/create_pet.dart'
    show CreatePetParams;
import 'package:petlytics/features/pet/domain/use_cases/update_pet.dart'
    show UpdatePetParams;
import 'package:petlytics/features/pet/presentation/cubit/pet_cubit.dart';
import 'package:petlytics/features/pet/presentation/cubit/pet_state.dart';
import 'package:petlytics/features/pet/presentation/extensions/pet_display_extensions.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_image.dart';

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '$month/$day/$year';
}

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
  final _birthDateController = TextEditingController();
  final _weightController = TextEditingController();
  final _microchipIdController = TextEditingController();

  final _imagePicker = ImagePicker();

  late PetSpecies _species;
  late PetSex _sex;
  late ReproductiveStatus _reproductiveStatus;

  DateTime? _birthDate;
  String? _pickedImagePath;
  String? _saveError;

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
        _birthDateController.text = _formatDate(pet.birthDate!);
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
    _birthDateController.dispose();
    _weightController.dispose();
    _microchipIdController.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState!.validate();

    if (!isValid) return;

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

  Future<void> _pickBirthDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      _birthDate = pickedDate;
      _birthDateController.text = _formatDate(pickedDate);
    });
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      requestFullMetadata: false,
    );

    if (image == null || !mounted) return;

    setState(() {
      _pickedImagePath = image.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pet == null ? 'Add pet' : 'Edit pet')),
      body: BlocConsumer<PetCubit, PetState>(
        listener: (context, state) {
          if (state case PetCreated() || PetUpdated()) {
            context.pop(true);
          }

          if (state case PetError(:final message)) {
            setState(() => _saveError = message);
          }
        },
        builder: (context, state) => AbsorbPointer(
          absorbing: state is PetLoading,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.pet == null
                              ? 'Meet your new companion'
                              : 'Edit pet details',
                          style: Theme.of(context).textTheme.headlineSmall,
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
                        Text(
                          'Basic details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        VerticalGap.md,

                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Name*'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
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
                          decoration: const InputDecoration(labelText: 'Breed'),
                        ),

                        VerticalGap.md,

                        Text(
                          'Health details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        VerticalGap.md,
                        DropdownButtonFormField<ReproductiveStatus>(
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(16),
                          initialValue: _reproductiveStatus,
                          items: ReproductiveStatus.values.map((status) {
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
                            TextFormField(
                              controller: _birthDateController,
                              readOnly: true,
                              onTap: _pickBirthDate,
                              decoration: InputDecoration(
                                labelText: 'Birth date',
                                hintText: 'mm/dd/yyyy',
                                suffixIcon: _birthDate == null
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _birthDate = null;
                                            _birthDateController.clear();
                                          });
                                        },
                                        tooltip: 'Clear birth date',
                                        icon: const Icon(Icons.clear),
                                      ),
                              ),
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
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }

                                final weight = double.tryParse(value.trim());

                                if (weight == null || !weight.isFinite) {
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

                        Text(
                          'Identification',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        VerticalGap.md,
                        TextFormField(
                          controller: _microchipIdController,
                          decoration: const InputDecoration(
                            labelText: 'Microchip ID',
                          ),
                        ),

                        VerticalGap.xl,

                        if (_saveError != null) ...[
                          Text(
                            _saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            semanticsLabel: 'Could not save pet: $_saveError',
                          ),
                          VerticalGap.md,
                        ],
                        BlocSelector<PetCubit, PetState, bool>(
                          selector: (state) => state is PetLoading,
                          builder: (context, isLoading) {
                            return FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.pet == null
                                          ? 'Add pet'
                                          : 'Save changes',
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
