import 'package:flutter/material.dart';

class AppFeedingIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const AppFeedingIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) => ImageIcon(
    const AssetImage('assets/icons/care/feeding.png'),
    size: size,
    color: color,
  );
}
