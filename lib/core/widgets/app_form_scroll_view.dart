import 'package:flutter/material.dart';

class AppFormScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppFormScrollView({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
    child: SingleChildScrollView(
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: child,
    ),
  );
}
