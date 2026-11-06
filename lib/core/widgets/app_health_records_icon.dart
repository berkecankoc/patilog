import 'package:flutter/material.dart';

class AppHealthRecordsIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const AppHealthRecordsIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) => ImageIcon(
    const AssetImage('assets/icons/care/health_records.png'),
    size: size,
    color: color,
  );
}
