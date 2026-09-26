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
  Future<String> save(String sourcePath) async {
    try {
      final documentDirectory = await getApplicationDocumentsDirectory();

      final imageDirectory = Directory(
        p.join(documentDirectory.path, 'pet_images'),
      );

      await imageDirectory.create(recursive: true);

      final extension = p.extension(sourcePath);
      final fileName =
          '${_idGenerator.generate()}${extension.isEmpty ? '.jpg' : extension}';

      final destinationPath = p.join(imageDirectory.path, fileName);

      final savedFile = await File(sourcePath).copy(destinationPath);

      return savedFile.path;
    } catch (_) {
      throw ImageStorageException();
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      throw ImageStorageException();
    }
  }
}
