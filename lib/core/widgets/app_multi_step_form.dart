import 'package:flutter/material.dart';
import 'package:petlytics/core/theme/app_spacing.dart';
import 'package:petlytics/core/widgets/app_error_feedback.dart';
import 'package:petlytics/core/widgets/app_form_actions.dart';
import 'package:petlytics/core/widgets/app_form_scroll_view.dart';
import 'package:petlytics/core/widgets/app_section_heading.dart';
import 'package:petlytics/core/widgets/app_keyboard.dart';

class AppFormStep {
  final String title;
  final Widget Function(BuildContext, ValueChanged<int> edit) builder;

  const AppFormStep({required this.title, required this.builder});
}

class AppMultiStepForm extends StatefulWidget {
  final Widget title;
  final double? toolbarHeight;
  final List<AppFormStep> steps;
  final bool editing;
  final int? initialStep;
  final bool Function() isSaving;
  bool get saving => isSaving();
  final bool allowPop;
  final bool canSubmit;
  final String submitLabel;
  final String? saveError;
  final Widget? status;
  final VoidCallback onSubmit;
  final VoidCallback onExit;
  final VoidCallback onChanged;

  const AppMultiStepForm({
    super.key,
    required this.title,
    this.toolbarHeight,
    required this.steps,
    required this.editing,
    this.initialStep,
    required this.isSaving,
    required this.allowPop,
    required this.canSubmit,
    required this.submitLabel,
    this.saveError,
    this.status,
    required this.onSubmit,
    required this.onExit,
    required this.onChanged,
  });

  @override
  State<AppMultiStepForm> createState() => _AppMultiStepFormState();
}

class _AppMultiStepFormState extends State<AppMultiStepForm> {
  late final _forms = List.generate(
    widget.steps.length,
    (_) => GlobalKey<FormState>(),
  );
  late int _step =
      widget.initialStep ?? (widget.editing ? widget.steps.length - 1 : 0);
  final _history = <int>[];

  int get _review => widget.steps.length - 1;
  bool get _returningToReview => _history.lastOrNull == _review;

  void _move(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  void _edit(int step) {
    if (!mounted || widget.saving || step == _step) return;
    _history.add(_step);
    _move(step);
  }

  bool _validate(int step) {
    final errors = _forms[step].currentState!.validateGranularly();
    if (errors.isEmpty) return true;
    final field = errors.first;
    field.context
        .findAncestorStateOfType<AppFormOptionalSectionState>()
        ?.expand();
    if (_step != step) _edit(step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && field.mounted) {
        Scrollable.ensureVisible(field.context, alignment: 0.1);
      }
    });
    return false;
  }

  void _continue() {
    if (!mounted || widget.saving || !_validate(_step)) return;
    if (_returningToReview) {
      _move(_history.removeLast());
    } else {
      _edit(_step + 1);
    }
  }

  void _back() {
    if (!mounted || widget.saving || widget.allowPop) return;
    if (_history.isNotEmpty) {
      _move(_history.removeLast());
    } else {
      widget.onExit();
    }
  }

  void _submit() {
    if (!mounted || widget.saving || !widget.canSubmit || _step != _review) {
      return;
    }
    for (var step = 0; step < _forms.length; step++) {
      if (!_validate(step)) return;
    }
    FocusScope.of(context).unfocus();
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: widget.allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: widget.title,
        toolbarHeight: widget.toolbarHeight,
        leading: BackButton(onPressed: widget.saving ? null : _back),
        actions: [
          if (MediaQuery.viewInsetsOf(context).bottom > 0)
            const AppHideKeyboardButton(),
        ],
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      if (widget.status != null)
                        Flexible(child: widget.status!),
                      if (widget.saveError != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight,
                          ),
                          child: AppErrorFeedback(
                            message: widget.saveError!,
                            retryLabel: 'Review changes',
                            onRetry: _step == _review
                                ? null
                                : () => _edit(_review),
                          ),
                        ),
                      Expanded(
                        // Keep field overlays inside the viewport, above the
                        // fixed actions and the keyboard.
                        child: Overlay.wrap(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: AbsorbPointer(
                                absorbing: widget.saving,
                                child: IndexedStack(
                                  index: _step,
                                  sizing: StackFit.expand,
                                  children: [
                                    for (
                                      var index = 0;
                                      index < widget.steps.length;
                                      index++
                                    )
                                      AppFormScrollView(
                                        key: ValueKey(index),
                                        padding: const EdgeInsets.all(
                                          AppSpacing.lg,
                                        ),
                                        child: Form(
                                          key: _forms[index],
                                          onChanged: widget.onChanged,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Semantics(
                                                liveRegion: true,
                                                child: Text(
                                                  'Step ${index + 1} of ${widget.steps.length} · ${widget.steps[index].title}',
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              LinearProgressIndicator(
                                                value:
                                                    (index + 1) /
                                                    widget.steps.length,
                                                semanticsLabel:
                                                    'Current form step',
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.lg,
                                              ),
                                              widget.steps[index].builder(
                                                context,
                                                _edit,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppFormNavigationActions(
                keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
                label: _step == _review
                    ? widget.submitLabel
                    : _returningToReview
                    ? 'Done'
                    : 'Continue',
                saving: widget.saving,
                onPressed: _step == _review
                    ? (widget.canSubmit ? _submit : null)
                    : _continue,
                onBack: !_returningToReview && _history.isNotEmpty
                    ? _back
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppFormReviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onEdit;

  const AppFormReviewSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = AppSectionHeading(title: title, icon: icon);
              final edit = TextButton(
                onPressed: onEdit,
                child: const Text('Edit'),
              );
              if (constraints.maxWidth < 360 &&
                  MediaQuery.textScalerOf(context).scale(14) >= 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: edit,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  edit,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    ),
  );
}

class AppFormOptionalSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;
  final ExpansibleController? controller;
  final ValueChanged<bool>? onExpansionChanged;

  const AppFormOptionalSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
    this.controller,
    this.onExpansionChanged,
  });

  @override
  State<AppFormOptionalSection> createState() => AppFormOptionalSectionState();
}

class AppFormOptionalSectionState extends State<AppFormOptionalSection> {
  final _ownedController = ExpansibleController();
  ExpansibleController get _controller => widget.controller ?? _ownedController;

  void expand() => _controller.expand();

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ExpansionTile(
      controller: _controller,
      maintainState: true,
      initiallyExpanded: widget.initiallyExpanded,
      onExpansionChanged: widget.onExpansionChanged,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(widget.icon, size: 20),
      title: Text(widget.title),
      childrenPadding: const EdgeInsets.all(AppSpacing.md),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [widget.child],
    ),
  );
}

class AppFormNavigationActions extends StatelessWidget {
  final String label;
  final bool saving;
  final VoidCallback? onPressed;
  final VoidCallback? onBack;
  final bool keyboardVisible;

  const AppFormNavigationActions({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
    this.onBack,
    this.keyboardVisible = false,
  });

  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('multi-step-form-actions'),
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final primary = AppFormActions(
                  label: label,
                  saving: saving,
                  onPressed: onPressed,
                );
                final showBack = onBack != null && !keyboardVisible;
                if (!showBack) return primary;
                final back = TextButton(
                  onPressed: saving ? null : onBack,
                  child: const Text('Back'),
                );
                if (constraints.maxWidth < 360 &&
                    MediaQuery.textScalerOf(context).scale(14) >= 21) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: back,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    back,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: primary),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
