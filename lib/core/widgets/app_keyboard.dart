import 'package:flutter/material.dart';

class AppKeyboard extends StatelessWidget {
  final Widget child;

  const AppKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: child,
  );
}

class AppHideKeyboardButton extends StatelessWidget {
  const AppHideKeyboardButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Hide keyboard',
    onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
    icon: const Icon(Icons.keyboard_hide_outlined),
  );
}
