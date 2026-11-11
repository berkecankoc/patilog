import 'package:flutter/material.dart';
import 'package:patilog/core/widgets/app_feeding_icon.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/utils/time_input_formatter.dart';
import 'package:patilog/core/widgets/app_date_field.dart';
import 'package:patilog/core/widgets/app_detail_field.dart';
import 'package:patilog/core/widgets/app_multi_step_form.dart';
import 'package:patilog/features/feeding/domain/entities/feeding_entry.dart';
import 'package:patilog/features/feeding/presentation/cubit/feeding_form_cubit.dart';
import 'package:patilog/features/feeding/presentation/utils/feeding_display.dart';
import 'package:patilog/features/feeding/presentation/widgets/feeding_form_shell.dart';
import 'package:patilog/l10n/generated/app_localizations.dart';

class FeedingEntryFormPage extends StatefulWidget {
  final String petId;
  final String? petName;
  final FeedingEntry? entry;
  final DateTime Function() now;
  const FeedingEntryFormPage({
    super.key,
    required this.petId,
    this.petName,
    this.entry,
    this.now = DateTime.now,
  });
  @override
  State<FeedingEntryFormPage> createState() => _FeedingEntryFormPageState();
}

class _FeedingEntryFormPageState extends State<FeedingEntryFormPage> {
  final _amount = TextEditingController();
  final _time = TextEditingController();
  final _food = TextEditingController();
  final _notes = TextEditingController();
  late final DateTime _initial =
      widget.entry?.givenAt.toLocal() ?? widget.now();
  late DateTime _date = DateUtils.dateOnly(_initial);
  String? _initialAmount;
  late final _initialTime = feedingTime(_initial.hour * 60 + _initial.minute);

  @override
  void initState() {
    super.initState();
    _time.text = _initialTime;
    _food.text = widget.entry?.foodName ?? '';
    _notes.text = widget.entry?.notes ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialAmount != null) return;
    _initialAmount = widget.entry == null
        ? ''
        : feedingAmount(context, widget.entry!.amountGrams);
    _amount.text = _initialAmount!;
  }

  bool get _changed =>
      _amount.text != _initialAmount ||
      _time.text != _initialTime ||
      !DateUtils.isSameDay(_date, _initial) ||
      _food.text != (widget.entry?.foodName ?? '') ||
      _notes.text != (widget.entry?.notes ?? '');
  DateTime? get _givenAt {
    final minute = parseFeedingTime(_time.text);
    if (minute == null) return null;
    if (DateUtils.isSameDay(_date, _initial) && _time.text == _initialTime) {
      return _initial;
    }
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      minute ~/ 60,
      minute % 60,
    );
  }

  @override
  void dispose() {
    for (final controller in [_amount, _time, _food, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _fields() {
    final s = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('feeding-amount'),
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: s.feedingAmount,
            suffixText: 'g',
            errorMaxLines: 3,
          ),
          validator: (value) => validateFeedingAmount(context, value),
        ),
        const SizedBox(height: 16),
        AppDateField(
          labelText: s.feedingDate,
          value: _date,
          firstDate: DateTime(1900),
          lastDate: widget.now(),
          onChanged: (date) {
            if (date != null) setState(() => _date = date);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('feeding-time'),
          controller: _time,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: const [TimeInputFormatter()],
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: s.feedingTime,
            helperText: s.time24Hint,
            errorMaxLines: 3,
          ),
          validator: (_) => _givenAt == null
              ? s.timeRangeInvalid
              : _givenAt!.isAfter(widget.now())
              ? s.givenTimeFuture
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return FeedingFormShell(
      petId: widget.petId,
      petName: widget.petName,
      title: widget.entry == null ? s.addFeeding : s.editFeeding,
      editing: widget.entry != null,
      hasChanges: () => _changed,
      onChanged: () => setState(() {}),
      onSubmit: () => context.read<FeedingFormCubit>().saveEntry(
        petId: widget.petId,
        existing: widget.entry,
        amountGrams: parseFeedingAmount(_amount.text)!,
        givenAt: _givenAt!,
        foodName: _food.text,
        notes: _notes.text,
      ),
      steps: [
        AppFormStep(title: s.feedingRecord, builder: (_, _) => _fields()),
        AppFormStep(
          title: s.review,
          builder: (_, edit) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.feedingRecordReview),
              const SizedBox(height: 16),
              AppFormReviewSection(
                title: s.feedingRecord,
                leading: const AppFeedingIcon(size: 20),
                onEdit: () => edit(0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDetailField(
                      label: s.feedingAmount,
                      value: s.feedingGrams(
                        parseFeedingAmount(_amount.text) == null
                            ? _amount.text
                            : feedingAmount(
                                context,
                                parseFeedingAmount(_amount.text)!,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppDetailField(
                      label: s.givenAt,
                      value:
                          '${MaterialLocalizations.of(context).formatShortDate(_date)} · ${_time.text}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppFormOptionalSection(
                title: s.feedingNotes,
                icon: Icons.notes_outlined,
                initiallyExpanded:
                    _food.text.isNotEmpty || _notes.text.isNotEmpty,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _food,
                      decoration: InputDecoration(
                        labelText: s.foodOptional,
                        errorMaxLines: 3,
                      ),
                      validator: (v) => (v?.trim().characters.length ?? 0) > 50
                          ? s.foodNameLimit
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notes,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: s.notesOptional,
                        errorMaxLines: 3,
                      ),
                      validator: (v) => (v?.trim().characters.length ?? 0) > 200
                          ? s.notesLimit200
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
