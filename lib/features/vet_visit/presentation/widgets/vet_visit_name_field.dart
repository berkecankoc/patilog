import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';

class VetVisitNameField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String>? onChanged;

  const VetVisitNameField({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    this.onChanged,
  });

  @override
  State<VetVisitNameField> createState() => _VetVisitNameFieldState();
}

class _VetVisitNameFieldState extends State<VetVisitNameField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim().toLowerCase();
    final options = _focus.hasFocus
        ? widget.suggestions
              .where(
                (name) =>
                    name.toLowerCase().contains(query) &&
                    name.toLowerCase() != query,
              )
              .take(5)
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: widget.label),
          onChanged: widget.onChanged,
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final name in options)
                  ActionChip(
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth - 48).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                    onPressed: () {
                      widget.controller.text = name;
                      widget.onChanged?.call(name);
                      _focus.unfocus();
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
