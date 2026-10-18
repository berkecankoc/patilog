import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:petlytics/core/theme/app_spacing.dart';

class AppSuggestionField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool loading;

  const AppSuggestionField({
    super.key,
    required this.label,
    required this.controller,
    required this.suggestions,
    this.onChanged,
    this.validator,
    this.loading = false,
  });

  @override
  State<AppSuggestionField> createState() => _AppSuggestionFieldState();
}

class _AppSuggestionFieldState extends State<AppSuggestionField> {
  final _focus = FocusNode();
  final _menu = MenuController();
  final _optionsFocus = FocusScopeNode();
  final _firstOptionFocus = FocusNode();
  late String _lastText;
  bool _dismissed = false;
  ValueNotifier<bool>? _scrolling;

  List<String> get _options {
    final query = widget.controller.text.trim().toLowerCase();
    return widget.suggestions
        .where(
          (name) =>
              name.toLowerCase().contains(query) && name.toLowerCase() != query,
        )
        .take(5)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    _focus.addListener(_changed);
    _optionsFocus.addListener(_updateMenu);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    if (_lastText != widget.controller.text) _dismissed = false;
    _lastText = widget.controller.text;
    setState(() {});
    _updateMenu();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrolling = Scrollable.maybeOf(context)?.position.isScrollingNotifier;
    if (identical(scrolling, _scrolling)) return;
    _scrolling?.removeListener(_updateMenu);
    _scrolling = scrolling;
    _scrolling?.addListener(_updateMenu);
  }

  @override
  void didUpdateWidget(AppSuggestionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _updateMenu();
  }

  void _updateMenu() {
    // Suggestions may arrive after typing; update the menu after the field builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Wait for the field's automatic scroll into view before opening.
      if (_scrolling?.value == true) return;
      if ((_focus.hasFocus || _optionsFocus.hasFocus) &&
          _options.isNotEmpty &&
          !_dismissed) {
        if (!_menu.isOpen) _menu.open();
      } else if (_menu.isOpen) {
        _menu.close();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _scrolling?.removeListener(_updateMenu);
    _optionsFocus.dispose();
    _firstOptionFocus.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: _menu,
        childFocusNode: _focus,
        onClose: () {
          final userScroll = Scrollable.maybeOf(
            context,
          )?.position.userScrollDirection;
          if (_options.isNotEmpty &&
              (_scrolling?.value != true ||
                  userScroll != ScrollDirection.idle)) {
            _dismissed = true;
          }
        },
        crossAxisUnconstrained: false,
        style: MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 240)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.md),
            ),
          ),
        ),
        menuChildren: [
          FocusScope(
            node: _optionsFocus,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, name) in _options.indexed)
                  TextFieldTapRegion(
                    child: MenuItemButton(
                      focusNode: index == 0 ? _firstOptionFocus : null,
                      requestFocusOnHover: false,
                      onPressed: () {
                        widget.controller.text = name;
                        widget.onChanged?.call(name);
                        _focus.unfocus();
                        _optionsFocus.unfocus();
                      },
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        builder: (context, controller, child) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () {
              if (_options.isEmpty) return;
              _dismissed = false;
              if (!_menu.isOpen) _menu.open();
              _firstOptionFocus.requestFocus();
            },
          },
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            onTap: () {
              _dismissed = false;
              _updateMenu();
            },
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.label,
              suffixIcon: widget.loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Loading suggestions',
                        ),
                      ),
                    )
                  : null,
            ),
            onChanged: widget.onChanged,
            validator: widget.validator,
          ),
        ),
      ),
    );
  }
}
