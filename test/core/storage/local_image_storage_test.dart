import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/services/id_generator.dart';
import 'package:petlytics/core/storage/local_image_storage.dart';

class FixedIdGenerator implements IdGenerator {
  @override
  String generate() => 'saved-photo';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late LocalImageStorage storage;
  late String imageDirectory;
  late String documentsPath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pet-images-');
    documentsPath = p.join(root.path, 'container', 'Documents');
    imageDirectory = p.join(documentsPath, 'pet_images');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsPath;
          }
          throw MissingPluginException();
        });
    storage = LocalImageStorage(FixedIdGenerator());
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  test('save copies the file and returns a portable filename', () async {
    final source = await File(
      p.join(root.path, 'picked.png'),
    ).writeAsBytes([1, 2, 3]);

    final saved = await storage.save(source.path);

    expect(saved, 'saved-photo.png');
    expect(await storage.resolvePath(saved), p.join(imageDirectory, saved));
    expect(await File(await storage.resolvePath(saved)).readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(await source.exists(), isTrue);
  });

  test(
    'saved references and legacy paths resolve after container moves',
    () async {
      final source = await File(
        p.join(root.path, 'picked.png'),
      ).writeAsBytes([1, 2, 3]);
      final saved = await storage.save(source.path);
      final reference = saved;
      final oldPath = await storage.resolvePath(saved);
      final moved = await Directory(
        p.join(root.path, 'container'),
      ).rename(p.join(root.path, 'new-container'));
      documentsPath = p.join(moved.path, 'Documents');
      final current = LocalImageStorage(FixedIdGenerator());

      expect(await File(oldPath).exists(), isFalse);
      expect(await File(await current.resolvePath(reference)).readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect(
        await current.resolvePath(oldPath),
        await current.resolvePath(reference),
      );

      await current.delete(oldPath);
      expect(
        await File(await current.resolvePath(reference)).exists(),
        isFalse,
      );
    },
  );

  test('delete accepts the persisted reference', () async {
    final source = await File(
      p.join(root.path, 'picked.png'),
    ).writeAsBytes([1]);
    final saved = await storage.save(source.path);

    await storage.delete(saved);

    expect(await File(await storage.resolvePath(saved)).exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('delete is harmless when the saved photo is already missing', () async {
    await storage.delete('missing.png');
  });

  test('save reports failure when the source is missing', () async {
    await expectLater(
      storage.save(p.join(root.path, 'missing.png')),
      throwsA(isA<ImageStorageException>()),
    );
  });

  test(
    'resolve reports failure when the platform directory is unavailable',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);

      await expectLater(
        storage.resolvePath('photo.png'),
        throwsA(isA<ImageStorageException>()),
      );
    },
  );
}
