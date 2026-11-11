import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/storage/image_storage.dart';

class PetImage extends StatefulWidget {
  final String? imagePath;

  /// Resolves a stored reference when true; previews a selected file when false.
  final bool isStored;
  final double size;
  final Widget Function(Widget? photo) builder;

  const PetImage({
    super.key,
    required this.imagePath,
    required this.size,
    required this.builder,
    this.isStored = true,
  });

  @override
  State<PetImage> createState() => _PetImageState();
}

class _PetImageState extends State<PetImage> {
  Future<String>? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolvePath();
  }

  @override
  void didUpdateWidget(PetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.isStored != widget.isStored) {
      _resolvePath();
    }
  }

  void _resolvePath() {
    final path = widget.imagePath;
    _resolvedPath = path == null
        ? null
        : widget.isStored
        ? context.read<ImageStorage>().resolvePath(path)
        : Future.value(path);
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedPath == null) return widget.builder(null);

    return FutureBuilder<String>(
      future: _resolvedPath,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return widget.builder(null);
        }

        return Image.file(
          File(snapshot.data!),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              widget.builder(
                frame != null || wasSynchronouslyLoaded ? child : null,
              ),
          errorBuilder: (context, error, stackTrace) => widget.builder(null),
        );
      },
    );
  }
}
