import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/image_storage.dart';

final class LocalImageStorage implements ImageStorage {
  final IdGenerator _idGenerator;
  const LocalImageStorage(this._idGenerator);

  @override
  Future<String> resolvePath(String storedPath) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      // App container paths can change; reuse only the filename from old paths.
      return p.join(documents.path, 'pet_images', p.basename(storedPath));
    } catch (_) {
      throw ImageStorageException();
    }
  }

  @override
  Future<String> save(String sourcePath) async {
    try {
      final extension = p.extension(sourcePath);
      final fileName =
          '${_idGenerator.generate()}${extension.isEmpty ? '.jpg' : extension}';

      final destinationPath = await resolvePath(fileName);
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
      final file = File(await resolvePath(path));

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      throw ImageStorageException();
    }
  }
}
