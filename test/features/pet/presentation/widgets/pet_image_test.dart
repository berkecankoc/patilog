import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petlytics/core/error/exception.dart';
import 'package:petlytics/core/storage/image_storage.dart';
import 'package:petlytics/features/pet/presentation/widgets/pet_image.dart';

class MockImageStorage extends Mock implements ImageStorage {}

void main() {
  late MockImageStorage storage;

  setUp(() => storage = MockImageStorage());

  Future<void> cachePhoto(WidgetTester tester, String path) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(1, 1)))!;
    picture.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      FileImage(File(path)),
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
    );
    addTearDown(PaintingBinding.instance.imageCache.clear);
  }

  Future<void> pumpPhoto(
    WidgetTester tester,
    String path, {
    bool isStored = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: RepositoryProvider<ImageStorage>.value(
        value: storage,
        child: PetImage(
          imagePath: path,
          isStored: isStored,
          size: 40,
          builder: (photo) => photo ?? const Text('No photo'),
        ),
      ),
    ),
  );

  for (final isStored in [true, false]) {
    testWidgets(
      isStored
          ? 'saved filename resolves to the current storage path'
          : 'selected photo previews directly without storage resolution',
      (tester) async {
        const path = '/current/documents/pet_images/photo.png';
        await cachePhoto(tester, path);
        when(
          () => storage.resolvePath('photo.png'),
        ).thenAnswer((_) async => path);

        await pumpPhoto(
          tester,
          isStored ? 'photo.png' : path,
          isStored: isStored,
        );
        await tester.pumpAndSettle();

        expect(find.text('No photo'), findsNothing);
        final image = tester.widget<Image>(find.byType(Image));
        expect((image.image as FileImage).file.path, path);
        if (isStored) {
          verify(() => storage.resolvePath('photo.png')).called(1);
        } else {
          verifyZeroInteractions(storage);
        }
      },
    );
  }

  testWidgets('changing a photo hides the old image while resolving', (
    tester,
  ) async {
    const path = '/current/documents/pet_images/old.png';
    await cachePhoto(tester, path);
    when(() => storage.resolvePath('old.png')).thenAnswer((_) async => path);
    final pending = Completer<String>();
    when(
      () => storage.resolvePath('new.png'),
    ).thenAnswer((_) => pending.future);
    await pumpPhoto(tester, 'old.png');
    await tester.pumpAndSettle();
    expect(find.text('No photo'), findsNothing);

    await pumpPhoto(tester, 'new.png');
    await tester.pump();
    expect(find.text('No photo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    pending.completeError(ImageStorageException());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage resolution failure shows the placeholder', (
    tester,
  ) async {
    when(
      () => storage.resolvePath('photo.png'),
    ).thenAnswer((_) async => throw ImageStorageException());
    await pumpPhoto(tester, 'photo.png');
    await tester.pumpAndSettle();
    expect(find.text('No photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
