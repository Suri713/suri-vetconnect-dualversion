import 'dart:io';

/// Uploads selected photos before saving the business; cleans up uploads from
/// an unsuccessful attempt instead of silently saving a partial photo list.
class BusinessPhotoUpload {
  static const maxPhotos = 6;
  static const maxBytes = 10 * 1024 * 1024;

  static Future<List<String>> save(
    List<File> files, {
    required Future<String?> Function(File) uploadFile,
    required Future<void> Function(String) deleteFile,
    required Future<bool> Function(List<String>) commit,
  }) async {
    final urls = await upload(
      files,
      uploadFile: uploadFile,
      deleteFile: deleteFile,
    );
    try {
      if (!await commit(urls)) throw StateError('Business could not be saved.');
      return urls;
    } catch (_) {
      await cleanup(urls, deleteFile: deleteFile);
      rethrow;
    }
  }

  static Future<List<String>> upload(
    List<File> files, {
    required Future<String?> Function(File) uploadFile,
    required Future<void> Function(String) deleteFile,
  }) async {
    if (files.length > maxPhotos) {
      throw ArgumentError('Choose up to six photos.');
    }
    for (final file in files) {
      if (await file.length() > maxBytes) {
        throw ArgumentError('Images must be under 10 MB.');
      }
    }
    final uploaded = <String>[];
    try {
      for (final file in files) {
        final url = await uploadFile(file);
        if (url == null) throw StateError('An image could not upload.');
        uploaded.add(url);
      }
      return uploaded;
    } catch (_) {
      await cleanup(uploaded, deleteFile: deleteFile);
      rethrow;
    }
  }

  static Future<void> cleanup(
    List<String> urls, {
    required Future<void> Function(String) deleteFile,
  }) async {
    for (final url in urls) {
      try {
        await deleteFile(url);
      } catch (_) {
        // A cleanup failure must not replace the original save/upload error.
      }
    }
  }
}
