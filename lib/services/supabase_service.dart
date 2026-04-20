import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getUserReminders() async {
    final supabase = Supabase.instance.client;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      // 🔥 ambil kost_id dari profile user
      final profile = await supabase
          .from('profiles')
          .select('kost_id')
          .eq('id', user.id)
          .single();

      final kostId = profile['kost_id'];
      if (kostId == null) return [];

      // 🔥 ambil reminder berdasarkan kost_id user
      final data = await supabase
          .from('reminders')
          .select()
          .eq('kost_id', kostId) // ⭐ INI KUNCI NYA
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("ERROR REMINDER SERVICE: $e");
      return [];
    }
  }

  // 🔥 PARSE MESSAGE (TETAP DIPAKAI)
  static Map<String, String>? parseReminder(String raw) {
    const kostPrefix = '[KOSTLY_KOST]';
    const tenantPrefix = '[KOSTLY_TENANT]';
    const titlePrefix = '[KOSTLY_TITLE]';
    const bodyPrefix = '[KOSTLY_BODY]';

    if (!raw.contains(titlePrefix) || !raw.contains(bodyPrefix)) {
      return null;
    }

    String? kostId;
    String? tenantId;

    final titleIndex = raw.indexOf(titlePrefix);
    final bodyIndex = raw.indexOf(bodyPrefix);

    if (titleIndex < 0 || bodyIndex < 0 || bodyIndex <= titleIndex) {
      return null;
    }

    if (raw.startsWith(kostPrefix)) {
      final tenantIndex = raw.indexOf(tenantPrefix, kostPrefix.length);
      if (tenantIndex >= 0 && tenantIndex < titleIndex) {
        kostId = raw.substring(kostPrefix.length, tenantIndex);
        tenantId = raw.substring(tenantIndex + tenantPrefix.length, titleIndex);
      }
    }

    final title = raw.substring(titleIndex + titlePrefix.length, bodyIndex);
    final body = raw.substring(bodyIndex + bodyPrefix.length);

    return {
      'title': title,
      'body': body,
      if (kostId != null) 'kost_id': kostId,
      if (tenantId != null) 'tenant_id': tenantId,
    };
  }
}
