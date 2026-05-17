import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kostly_pa/services/supabase_service.dart';

class MediaService {
  MediaService._();

  static final ImagePicker _picker = ImagePicker();
  static final _supabase = SupabaseService.client;

  static Future<XFile?> pickImage(BuildContext context) async {
    final source = await _showImageSourcePicker(context);
    if (source == null) return null;
    return _pickImageSmart(source: source);
  }

  static Future<ImageSource?> _showImageSourcePicker(
    BuildContext context,
  ) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFFFFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0D2C1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Pilih sumber foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D241A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gunakan kamera atau pilih gambar dari galeri.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B6257),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E3CF),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF9C5A1A),
                  ),
                ),
                title: const Text('Kamera'),
                subtitle: const Text('Ambil foto baru sekarang'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E3CF),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF9C5A1A),
                  ),
                ),
                title: const Text('Galeri'),
                subtitle: const Text('Pilih foto yang sudah ada'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<XFile?> _pickImageSmart({
    required ImageSource source,
  }) async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        return _picker.pickImage(
          source: source,
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
