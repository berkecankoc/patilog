import 'package:flutter/material.dart';

class AppDateField extends StatefulWidget {
  final String labelText;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;

  const AppDateField({
    super.key,
    required this.labelText,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.clearable = false,
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
    FocusScope.of(context).unfocus();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.value ?? widget.lastDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (date != null && mounted) widget.onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final canClear = widget.clearable && widget.value != null;
    return TextField(
      controller: _controller,
      readOnly: true,
      onTap: _pickDate,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          tooltip:
              '${canClear ? 'Clear' : 'Choose'} ${widget.labelText.toLowerCase()}',
          onPressed: canClear ? () => widget.onChanged(null) : _pickDate,
          icon: Icon(canClear ? Icons.clear : Icons.calendar_today_outlined),
        ),
      ),
    );
  }
}
