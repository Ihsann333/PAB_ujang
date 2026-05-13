import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class MediaService {
  MediaService._();

  static final ImagePicker _picker = ImagePicker();
  static final _supabase = SupabaseService.client;

  static Future<XFile?> takePhoto() {
    return _pickImageSmart();
  }

  static Future<XFile?> _pickImageSmart() async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        return _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1600,
        );
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.bytes == null) return null;
      return XFile.fromData(
        file.bytes!,
        name: file.name,
        mimeType: file.extension != null ? 'image/${file.extension}' : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String bucket,
    required String folder,
    required String fileName,
  }) async {
    final path = '$folder/$fileName';

    await _supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage.from(bucket).getPublicUrl(path);
  }
}
