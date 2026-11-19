import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:patilog/core/storage/image_storage.dart';

class PetImage extends StatelessWidget {
  /// Avatars up to this size share one decoded photo, so a photo decoded on
  /// one screen appears immediately on the others.
  static const _sharedDecodeSize = 120.0;

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
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null) return builder(null);

    // Synchronous resolution lets a cached photo render in the first frame.
    final file = File(
      isStored ? context.read<ImageStorage>().resolvePath(path) : path,
    );
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final extent = (math.max(size, _sharedDecodeSize) * pixelRatio).ceil();
    return Image(
      image: PetPhotoImage(file, extent),
      width: size,
      height: size,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          builder(frame != null || wasSynchronouslyLoaded ? child : null),
      errorBuilder: (context, error, stackTrace) => builder(null),
    );
  }
}

/// Decodes a photo file with its shorter side at most [extent] pixels.
///
/// Full-resolution camera photos take tens of megabytes each once decoded and
/// push each other out of the image cache; this size still covers a square of
/// [extent] pixels without upscaling.
@immutable
class PetPhotoImage extends ImageProvider<PetPhotoImage> {
  final File file;
  final int extent;

  const PetPhotoImage(this.file, this.extent);

  @override
  Future<PetPhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    PetPhotoImage key,
    ImageDecoderCallback decode,
  ) {
    final ImageProvider<FileImage> source = FileImage(key.file);
    return source.loadImage(
      FileImage(key.file),
      (buffer, {getTargetSize}) => decode(
        buffer,
        // Constraining one side lets the decoder keep the aspect ratio.
        getTargetSize: (width, height) => width <= height
            ? ui.TargetImageSize(width: math.min(width, key.extent))
            : ui.TargetImageSize(height: math.min(height, key.extent)),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PetPhotoImage &&
      other.file.path == file.path &&
      other.extent == extent;

  @override
  int get hashCode => Object.hash(file.path, extent);

  @override
  String toString() => 'PetPhotoImage("${file.path}", extent: $extent)';
}
