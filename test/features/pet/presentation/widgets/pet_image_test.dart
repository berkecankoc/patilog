import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:patilog/core/storage/image_storage.dart';
import 'package:patilog/features/pet/presentation/widgets/pet_image.dart';

class MockImageStorage extends Mock implements ImageStorage {}

void main() {
  late MockImageStorage storage;

  setUp(() => storage = MockImageStorage());

  int sharedExtent(WidgetTester tester) =>
      (120 * tester.view.devicePixelRatio).ceil();

  Future<void> cachePhoto(WidgetTester tester, String path) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(1, 1)))!;
    picture.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      PetPhotoImage(File(path), sharedExtent(tester)),
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
    );
    addTearDown(PaintingBinding.instance.imageCache.clear);
  }

  Widget photo(String path, {bool isStored = true, double size = 40}) =>
      MaterialApp(
        home: RepositoryProvider<ImageStorage>.value(
          value: storage,
          child: PetImage(
            imagePath: path,
            isStored: isStored,
            size: size,
            builder: (photo) => photo ?? const Text('No photo'),
          ),
        ),
      );

  PetPhotoImage shownPhoto(WidgetTester tester) =>
      tester.widget<Image>(find.byType(Image)).image as PetPhotoImage;

  for (final isStored in [true, false]) {
    testWidgets(
      isStored
          ? 'saved filename resolves to the current storage path'
          : 'selected photo previews directly without storage resolution',
      (tester) async {
        const path = '/current/documents/pet_images/photo.png';
        await cachePhoto(tester, path);
        when(() => storage.resolvePath('photo.png')).thenReturn(path);

        await tester.pumpWidget(
          photo(isStored ? 'photo.png' : path, isStored: isStored),
        );

        expect(find.text('No photo'), findsNothing);
        expect(shownPhoto(tester).file.path, path);
        if (isStored) {
          verify(() => storage.resolvePath('photo.png')).called(greaterThan(0));
        } else {
          verifyZeroInteractions(storage);
        }
      },
    );
  }

  testWidgets(
    'a photo decoded on one screen appears in the first frame of another',
    (tester) async {
      const path = '/current/documents/pet_images/photo.png';
      await cachePhoto(tester, path);
      when(() => storage.resolvePath('photo.png')).thenReturn(path);

      // Each size is a fresh widget, as when another page builds an avatar.
      for (final size in [28.0, 40.0, 56.0, 120.0]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(photo('photo.png', size: size));

        expect(find.text('No photo'), findsNothing, reason: 'size $size');
        expect(shownPhoto(tester).extent, sharedExtent(tester));
      }
    },
  );

  testWidgets('photos larger than shared avatars decode at their own size', (
    tester,
  ) async {
    when(() => storage.resolvePath('photo.png')).thenReturn('/photo.png');

    await tester.pumpWidget(photo('photo.png', size: 200));

    expect(
      shownPhoto(tester).extent,
      (200 * tester.view.devicePixelRatio).ceil(),
    );
  });

  testWidgets('changing a photo hides the old image while the new one loads', (
    tester,
  ) async {
    const path = '/current/documents/pet_images/old.png';
    await cachePhoto(tester, path);
    when(() => storage.resolvePath('old.png')).thenReturn(path);
    when(() => storage.resolvePath('new.png'))
        .thenReturn('/current/documents/pet_images/new.png');
    await tester.pumpWidget(photo('old.png'));
    expect(find.text('No photo'), findsNothing);

    await tester.pumpWidget(photo('new.png'));

    expect(find.text('No photo'), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('a missing photo file shows the placeholder', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('pet-image-'),
    ))!;
    addTearDown(() => tester.runAsync(() => directory.delete(recursive: true)));
    addTearDown(PaintingBinding.instance.imageCache.clear);
    final path = p.join(directory.path, 'missing.png');
    when(() => storage.resolvePath('missing.png')).thenReturn(path);

    await tester.pumpWidget(photo('missing.png'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('No photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('decoding', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('pet-photo-');
    });

    tearDown(() => directory.delete(recursive: true));

    Future<File> writePng(int width, int height) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return File(p.join(directory.path, '${width}x$height.png'))
          .writeAsBytes(bytes!.buffer.asUint8List());
    }

    Future<(int, int)> decodedSize(File file, int extent) async {
      final provider = PetPhotoImage(file, extent);
      addTearDown(() => provider.evict());
      final completer = Completer<ImageInfo>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (info, _) => completer.complete(info),
        onError: completer.completeError,
      );
      stream.addListener(listener);
      final info = await completer.future;
      final size = (info.image.width, info.image.height);
      stream.removeListener(listener);
      info.dispose();
      return size;
    }

    for (final (width, height, expected) in [
      (400, 200, (200, 100)),
      (200, 400, (100, 200)),
      (300, 300, (100, 100)),
      (60, 120, (60, 120)),
    ]) {
      test('${width}x$height keeps its aspect ratio with the shorter side '
          'covering 100 pixels without upscaling', () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final file = await writePng(width, height);

        expect(await decodedSize(file, 100), expected);
      });
    }
  });
}
