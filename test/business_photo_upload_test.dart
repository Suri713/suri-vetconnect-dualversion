import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetconnect/services/business_photo_upload.dart';

void main() {
  late Directory temporary;
  late List<File> images;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('business-photo-test-');
    images = [
      await File('${temporary.path}/one.png').writeAsBytes([1]),
      await File('${temporary.path}/two.png').writeAsBytes([2]),
    ];
  });
  tearDown(() => temporary.delete(recursive: true));

  test('commits all photo URLs only after uploads finish', () async {
    final events = <String>[];
    final urls = await BusinessPhotoUpload.save(
      images,
      uploadFile: (file) async {
        events.add('upload');
        return 'https://example.com/${file.uri.pathSegments.last}';
      },
      deleteFile: (_) async {
        events.add('delete');
      },
      commit: (urls) async {
        events.add('commit');
        expect(urls, hasLength(2));
        return true;
      },
    );
    expect(urls, hasLength(2));
    expect(events, ['upload', 'upload', 'commit']);
  });
  test(
    'failed upload cleans up its earlier uploads without replacing a profile',
    () async {
      var count = 0;
      var committed = false;
      final removed = <String>[];
      await expectLater(
        BusinessPhotoUpload.save(
          images,
          uploadFile: (_) async => ++count == 1 ? 'first-url' : null,
          deleteFile: (url) async {
            removed.add(url);
          },
          commit: (_) async {
            committed = true;
            return true;
          },
        ),
        throwsStateError,
      );
      expect(committed, isFalse);
      expect(removed, ['first-url']);
    },
  );
  test('failed profile save cleans up new photos', () async {
    final removed = <String>[];
    await expectLater(
      BusinessPhotoUpload.save(
        [images.first],
        uploadFile: (_) async => 'new-url',
        deleteFile: (url) async {
          removed.add(url);
        },
        commit: (_) async => false,
      ),
      throwsStateError,
    );
    expect(removed, ['new-url']);
  });
  test('too many or oversized images are rejected before any upload', () async {
    var uploaded = false;
    Future<String?> upload(File file) async {
      uploaded = true;
      return 'url';
    }

    await expectLater(
      BusinessPhotoUpload.upload(
        List.filled(7, images.first),
        uploadFile: upload,
        deleteFile: (_) async {},
      ),
      throwsArgumentError,
    );
    final file = await images.first.open(mode: FileMode.write);
    await file.truncate(BusinessPhotoUpload.maxBytes + 1);
    await file.close();
    await expectLater(
      BusinessPhotoUpload.upload(
        [images.first],
        uploadFile: upload,
        deleteFile: (_) async {},
      ),
      throwsArgumentError,
    );
    expect(uploaded, isFalse);
  });
}
