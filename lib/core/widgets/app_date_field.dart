import 'package:flutter/material.dart';
import 'package:petlytics/l10n/generated/app_localizations.dart';

class AppDateField extends StatefulWidget {
  final String labelText;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final bool readOnly;
  final String? errorText;

  const AppDateField({
    super.key,
    required this.labelText,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.clearable = false,
    this.readOnly = false,
    this.errorText,
  });

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  final _controller = TextEditingController();

  void _updateText() {
    _controller.text = widget.value == null
        ? ''
        : MaterialLocalizations.of(context).formatShortDate(widget.value!);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateText();
  }

  @override
  void didUpdateWidget(AppDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _updateText();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (widget.readOnly) return;
    FocusScope.of(context).unfocus();
    final candidate = DateUtils.dateOnly(widget.value ?? DateTime.now());
    final first = DateUtils.dateOnly(widget.firstDate);
    final last = DateUtils.dateOnly(widget.lastDate);
    final initial = candidate.isBefore(first)
        ? first
        : candidate.isAfter(last)
        ? last
        : candidate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (date != null && mounted && !widget.readOnly) widget.onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final canClear =
        !widget.readOnly && widget.clearable && widget.value != null;
    return TextField(
      controller: _controller,
      readOnly: true,
      onTap: widget.readOnly ? null : _pickDate,
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: widget.errorText,
        suffixIcon: widget.readOnly
            ? const Icon(Icons.calendar_today_outlined)
            : IconButton(
                tooltip: canClear
                    ? AppLocalizations.of(
                        context,
                      ).clearDateField(widget.labelText)
                    : AppLocalizations.of(
                        context,
                      ).chooseDateField(widget.labelText),
                onPressed: canClear ? () => widget.onChanged(null) : _pickDate,
                icon: Icon(
                  canClear ? Icons.clear : Icons.calendar_today_outlined,
                ),
              ),
      ),
    );
  }
}
