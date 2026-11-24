import 'package:flutter/widgets.dart';

/// Holds status strips such as AppErrorFeedback above Expanded content.
///
/// The strips take at most [maxHeightFraction] of the screen, so the content
/// below always keeps all remaining height. A single strip scrolls its message
/// above a visible action; several strips scroll together. Wrapping strips in
/// Flexible beside Expanded instead would split the free space by flex and
/// leave the content only half of it.
class AppFeedbackArea extends StatelessWidget {
  final List<Widget> children;
  const AppFeedbackArea({super.key, required this.children});

  /// Leaves at least half of a short or large-text screen to the content.
  static const maxHeightFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      child: children.length == 1
          ? children.single
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
    );
  }
}
