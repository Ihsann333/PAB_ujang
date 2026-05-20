import 'dart:async';
import 'dart:collection';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class KostLocationData {
  const KostLocationData({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  String get coordinateLabel =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get mapsUrl => KostLocationService.buildMapsUrl(latitude, longitude);
}

class KostLocationService {
  KostLocationService._();

  static Future<KostLocationData> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi di perangkat sedang mati.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak. Aktifkan izin lokasi terlebih dulu.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkannya.',
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        timeLimit: const Duration(seconds: 12),
      );
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        throw Exception(
          'Gagal mengambil lokasi (timeout). Coba aktifkan GPS lalu ulangi.',
        );
      }
    }

    return KostLocationData(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static double? readLatitude(Map? data) {
    if (data == null) return null;
    return _readDouble(
      data,
      const ['latitude', 'lat', 'location_lat', 'location_latitude'],
    );
  }

  static double? readLongitude(Map? data) {
    if (data == null) return null;
    return _readDouble(
      data,
      const ['longitude', 'lng', 'location_lng', 'location_longitude'],
    );
  }

  static String? readMapsUrl(Map? data) {
    if (data == null) return null;

    for (final key in const [
      'maps_url',
      'map_url',
      'location_url',
      'google_maps_url',
    ]) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final latitude = readLatitude(data);
    final longitude = readLongitude(data);
    if (latitude == null || longitude == null) return null;
    return buildMapsUrl(latitude, longitude);
  }

  static bool hasLocation(Map? data) {
    return readLatitude(data) != null && readLongitude(data) != null;
  }

  static String coordinateLabelFromMap(Map? data, {String fallback = '-'}) {
    final latitude = readLatitude(data);
    final longitude = readLongitude(data);
    if (latitude == null || longitude == null) return fallback;
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  static String buildMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  static Future<void> openMap(Map? data) async {
    final url = readMapsUrl(data);
    if (url == null || url.isEmpty) {
      throw Exception('Lokasi kost belum tersedia.');
    }

    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Gagal membuka peta lokasi kost.');
    }
  }

  static Future<Map<String, dynamic>?> saveKostWithLocation({
    required SupabaseClient supabase,
    String? kostId,
    required Map<String, dynamic> basePayload,
    KostLocationData? location,
  }) async {
    final payloads = _buildPayloadVariants(basePayload, location);
    Object? lastError;

    for (final payload in payloads) {
      try {
        if (kostId == null) {
          final inserted = await supabase
              .from('kosts')
              .insert(payload)
              .select()
              .single();
          return Map<String, dynamic>.from(inserted);
        } else {
          final updated = await supabase
              .from('kosts')
              .update(payload)
              .eq('id', kostId)
              .select()
              .maybeSingle();
          if (updated != null) return Map<String, dynamic>.from(updated);
        }
        return null;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) throw lastError;
  }

  static List<Map<String, dynamic>> _buildPayloadVariants(
    Map<String, dynamic> basePayload,
    KostLocationData? location,
  ) {
    if (location == null) return [Map<String, dynamic>.from(basePayload)];

    final variants = LinkedHashMap<String, Map<String, dynamic>>();

    void addVariant(Map<String, dynamic> extra) {
      final payload = Map<String, dynamic>.from(basePayload)..addAll(extra);
      variants[payload.keys.join('|') + payload.values.join('|')] = payload;
    }

    addVariant({
      'latitude': location.latitude,
      'longitude': location.longitude,
      'maps_url': location.mapsUrl,
    });
    addVariant({
      'latitude': location.latitude,
      'longitude': location.longitude,
    });
    addVariant({
      'lat': location.latitude,
      'lng': location.longitude,
      'maps_url': location.mapsUrl,
    });
    addVariant({
      'lat': location.latitude,
      'lng': location.longitude,
    });
    addVariant({
      'location_lat': location.latitude,
      'location_lng': location.longitude,
      'location_url': location.mapsUrl,
    });
    addVariant({
      'location_lat': location.latitude,
      'location_lng': location.longitude,
    });
    addVariant({});

    return variants.values.toList();
  }

  static double? _readDouble(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
