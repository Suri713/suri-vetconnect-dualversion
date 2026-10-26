import 'dart:io';

import 'package:image_picker/image_picker.dart';

class MediaPickerService {
  MediaPickerService._();

  static final ImagePicker _imagePicker = ImagePicker();

  static Future<List<File>> pickBusinessImages({required int remaining}) async {
    if (remaining <= 0) return [];
    if (remaining == 1) {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        requestFullMetadata: false,
      );
      return image == null ? [] : [File(image.path)];
    }
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
      limit: remaining,
      requestFullMetadata: false,
    );
    return images.take(remaining).map((image) => File(image.path)).toList();
  }

  static Future<File?> pickImageFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null || image.path.isEmpty) {
      return null;
    }

    return File(image.path);
  }
}
