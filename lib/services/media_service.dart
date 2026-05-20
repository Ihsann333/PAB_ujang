import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadedImage {
  const UploadedImage({
    required this.publicUrl,
    required this.storagePath,
  });

  final String publicUrl;
  final String storagePath;
}

class MediaService {
  MediaService._();

  static const String bucketName = 'kostly-media';

  static final ImagePicker _picker = ImagePicker();
  static final _supabase = SupabaseService.client;

  static Future<XFile?> pickImage(BuildContext context) async {
    final source = await _showImageSourcePicker(context);
    if (source == null) return null;
    return _pickImageSmart(source: source);
  }

  static Future<String?> pickAndUploadProfilePhoto(
    BuildContext context, {
    required String userId,
    required String filePrefix,
  }) async {
    final photo = await pickImage(context);
    if (photo == null) return null;

    final bytes = await photo.readAsBytes();
    final uploaded = await uploadProfilePhoto(
      userId: userId,
      bytes: bytes,
      originalFileName: photo.name,
      filePrefix: filePrefix,
    );
    await upsertProfileImage(
      userId: userId,
      imageUrl: uploaded.publicUrl,
      storagePath: uploaded.storagePath,
    );
    return uploaded.publicUrl;
  }

  static Future<String?> pickAndUploadKostPhoto(
    BuildContext context, {
    required String kostId,
    String filePrefix = 'kost',
  }) async {
    final photo = await pickImage(context);
    if (photo == null) return null;

    final bytes = await photo.readAsBytes();
    final uploaded = await uploadKostPhoto(
      kostId: kostId,
      bytes: bytes,
      originalFileName: photo.name,
      filePrefix: filePrefix,
    );
    await upsertKostImage(
      kostId: kostId,
      imageUrl: uploaded.publicUrl,
      storagePath: uploaded.storagePath,
    );
    return uploaded.publicUrl;
  }

  static Future<UploadedImage> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String originalFileName,
    required String filePrefix,
  }) async {
    return uploadImageBytes(
      bytes: bytes,
      bucket: bucketName,
      folder: 'profiles/$userId',
      fileName: buildFileName(
        prefix: '${filePrefix}_$userId',
        originalFileName: originalFileName,
      ),
    );
  }

  static Future<UploadedImage> uploadKostPhoto({
    required String kostId,
    required Uint8List bytes,
    required String originalFileName,
    String filePrefix = 'kost',
  }) async {
    return uploadImageBytes(
      bytes: bytes,
      bucket: bucketName,
      folder: 'kosts/$kostId',
      fileName: buildFileName(
        prefix: '${filePrefix}_$kostId',
        originalFileName: originalFileName,
      ),
    );
  }

  static String buildFileName({
    required String prefix,
    required String originalFileName,
  }) {
    final normalizedPrefix = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final extension = _extractExtension(originalFileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${normalizedPrefix}_$timestamp.$extension';
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
              Text(
                _supportsDirectCamera
                    ? 'Gunakan kamera atau pilih gambar dari galeri.'
                    : 'Perangkat ini mendukung galeri. Kamera akan memakai fallback jika tersedia.',
                style: const TextStyle(
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
                subtitle: Text(
                  _supportsDirectCamera
                      ? 'Ambil foto baru sekarang'
                      : 'Pilih file gambar jika kamera tidak tersedia',
                ),
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
      if (_shouldUseImagePicker) {
        return _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 1600,
          preferredCameraDevice: CameraDevice.rear,
        );
      }

      // Desktop fallback: gallery/file selection is reliable, camera support is not.
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
        mimeType: _guessMimeType(file.name),
      );
    } catch (e) {
      debugPrint('MEDIA PICK ERROR: $e');
      return null;
    }
  }

  static Future<UploadedImage> uploadImageBytes({
    required Uint8List bytes,
    required String bucket,
    required String folder,
    required String fileName,
  }) async {
    final normalizedFolder = folder.replaceAll(RegExp(r'[/\\\\]+'), '/');
    final path = '$normalizedFolder/$fileName';

    await _supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            cacheControl: '3600',
            contentType: _guessMimeType(fileName),
          ),
        );

    return UploadedImage(
      publicUrl: _supabase.storage.from(bucket).getPublicUrl(path),
      storagePath: path,
    );
  }

  static Future<void> upsertProfileImage({
    required String userId,
    required String imageUrl,
    String? storagePath,
  }) async {
    await _supabase
        .from('images')
        .delete()
        .eq('image_type', 'profile')
        .eq('user_id', userId);

    await _supabase.from('images').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'storage_path': storagePath,
      'image_type': 'profile',
    });
  }

  static Future<void> upsertKostImage({
    required String kostId,
    required String imageUrl,
    String? storagePath,
  }) async {
    await _supabase
        .from('images')
        .delete()
        .eq('image_type', 'kost')
        .eq('kost_id', kostId);

    await _supabase.from('images').insert({
      'kost_id': kostId,
      'image_url': imageUrl,
      'storage_path': storagePath,
      'image_type': 'kost',
    });
  }

  static Future<String?> getProfileImageUrl(String userId) async {
    final row = await _supabase
        .from('images')
        .select('image_url')
        .eq('image_type', 'profile')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['image_url']?.toString();
  }

  static Future<String?> getKostImageUrl(String kostId) async {
    final row = await _supabase
        .from('images')
        .select('image_url')
        .eq('image_type', 'kost')
        .eq('kost_id', kostId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['image_url']?.toString();
  }

  static Future<Map<String, dynamic>> attachProfileImage(
    Map<String, dynamic> profile,
  ) async {
    final userId = profile['id']?.toString();
    if (userId == null || userId.isEmpty) return profile;

    final imageUrl = await getProfileImageUrl(userId);
    return {
      ...profile,
      'profile_photo_url': imageUrl,
    };
  }

  static Future<Map<String, dynamic>> attachKostImage(
    Map<String, dynamic> kost,
  ) async {
    final kostId = kost['id']?.toString();
    if (kostId == null || kostId.isEmpty) return kost;

    final imageUrl = await getKostImageUrl(kostId);
    return {
      ...kost,
      'photo_url': imageUrl,
    };
  }

  static Future<List<Map<String, dynamic>>> attachKostImages(
    List<Map<String, dynamic>> kosts,
  ) async {
    final List<Map<String, dynamic>> enriched = [];
    for (final kost in kosts) {
      enriched.add(await attachKostImage(kost));
    }
    return enriched;
  }

  static bool get _shouldUseImagePicker {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get _supportsDirectCamera {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static String _extractExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'jpg';

    final extension = parts.last.trim().toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'heic':
        return extension;
      default:
        return 'jpg';
    }
  }

  static String _guessMimeType(String fileName) {
    switch (_extractExtension(fileName)) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
