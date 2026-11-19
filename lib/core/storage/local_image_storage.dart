import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:patilog/core/error/exception.dart';
import 'package:patilog/core/services/id_generator.dart';
import 'package:patilog/core/storage/image_storage.dart';

final class LocalImageStorage implements ImageStorage {
  final IdGenerator _idGenerator;

  /// The app documents directory of the current launch.
  final String _documentsPath;

  const LocalImageStorage(this._idGenerator, this._documentsPath);

  @override
  String resolvePath(String storedPath) =>
      // App container paths can change; reuse only the filename from old paths.
      p.join(_documentsPath, 'pet_images', p.basename(storedPath));

  @override
  Future<String> save(String sourcePath) async {
    try {
      final extension = p.extension(sourcePath);
      final fileName =
          '${_idGenerator.generate()}${extension.isEmpty ? '.jpg' : extension}';

      final destinationPath = resolvePath(fileName);
      await File(destinationPath).parent.create(recursive: true);

      await File(sourcePath).copy(destinationPath);

      return fileName;
    } catch (_) {
      throw ImageStorageException();
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(resolvePath(path));

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      throw ImageStorageException();
    }
  }
}
