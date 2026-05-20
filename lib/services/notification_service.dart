import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kostly_pa/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSyncEvent {
  const NotificationSyncEvent({
    required this.scope,
    required this.table,
    this.recordId,
  });

  final String scope;
  final String table;
  final String? recordId;
}

class AppNotificationService {
  AppNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<NotificationSyncEvent> _eventController =
      StreamController<NotificationSyncEvent>.broadcast();

  static final List<RealtimeChannel> _channels = [];
  static final Set<String> _handledRealtimeKeys = <String>{};

  static bool _initialized = false;
  static String? _activeRealtimeUserId;

  static Stream<NotificationSyncEvent> get events => _eventController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'kostly_notifications',
      'Kostly Notifications',
      channelDescription: 'Notifikasi aplikasi Kostly',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static Future<void> startRealtimeSyncForCurrentUser() async {
    await initialize();

    final supabase = SupabaseService.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      await stopRealtimeSync();
      return;
    }

    if (_activeRealtimeUserId == user.id && _channels.isNotEmpty) {
      return;
    }

    await stopRealtimeSync();

    final profile = await supabase
        .from('profiles')
        .select('id, role, kost_id')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) return;

    _activeRealtimeUserId = user.id;

    final role = profile['role']?.toString();
    if (role == 'user') {
      await _attachUserReminderListener(
        userId: user.id,
        kostId: profile['kost_id']?.toString(),
      );
      _attachUserPaymentListener(userId: user.id);
      return;
    }

    if (role == 'owner') {
      final kosts = await supabase
          .from('kosts')
          .select('id')
          .eq('owner_id', user.id);
      final kostIds = (kosts as List)
          .map((item) => item['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      _attachOwnerPaymentListener(kostIds);
      _attachOwnerExitRequestListener(kostIds);
      return;
    }

    if (role == 'admin') {
      _attachAdminOwnerApprovalListener();
      _attachAdminKostApprovalListener();
    }
  }

  static Future<void> stopRealtimeSync() async {
    final supabase = SupabaseService.client;

    for (final channel in _channels) {
      await supabase.removeChannel(channel);
    }

    _channels.clear();
    _activeRealtimeUserId = null;
  }

  static Future<void> _attachUserReminderListener({
    required String userId,
    required String? kostId,
  }) async {
    if (kostId == null || kostId.isEmpty) return;

    final supabase = SupabaseService.client;
    final channel = supabase
        .channel('kostly-user-reminders-$userId-$kostId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reminders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'kost_id',
            value: kostId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            if (row.isEmpty) return;

            final reminder = Map<String, dynamic>.from(row);
            final matches = SupabaseService.isReminderForUser(
              reminder,
              currentKostId: kostId,
              currentUserId: userId,
            );
            if (!matches) return;

            final key = _realtimeKey(
              scope: 'user_reminder',
              row: reminder,
              rawDiscriminator:
                  reminder['created_at']?.toString() ?? reminder['message'],
            );
            if (!_markHandled(key)) return;

            await show(
              title: SupabaseService.reminderTitle(reminder),
              body: SupabaseService.reminderBody(reminder),
            );

            _emit(
              const NotificationSyncEvent(
                scope: 'user_reminders',
                table: 'reminders',
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  static void _attachUserPaymentListener({required String userId}) {
    final supabase = SupabaseService.client;
    final channel = supabase
        .channel('kostly-user-payments-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payments',
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (!_paymentBelongsToUser(row, userId)) return;

            final status = row['status']?.toString().toLowerCase() ?? '';
            final key = _realtimeKey(
              scope: 'user_payment',
              row: row,
              rawDiscriminator: '$status-${row['updated_at'] ?? row['paid_at']}',
            );
            if (!_markHandled(key)) return;

            final notification = _userPaymentNotification(status);
            if (notification != null) {
              await show(title: notification.$1, body: notification.$2);
            }

            _emit(
              NotificationSyncEvent(
                scope: 'user_payments',
                table: 'payments',
                recordId: row['id']?.toString(),
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  static void _attachOwnerPaymentListener(Set<String> kostIds) {
    if (kostIds.isEmpty) return;

    final supabase = SupabaseService.client;
    final channel = supabase
        .channel('kostly-owner-payments-${_activeRealtimeUserId ?? 'owner'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'payments',
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final kostId = row['kost_id']?.toString();
            if (kostId == null || !kostIds.contains(kostId)) return;

            final status = row['status']?.toString().toLowerCase() ?? '';
            if (status != 'pending') return;

            final key = _realtimeKey(
              scope: 'owner_payment_insert',
              row: row,
              rawDiscriminator:
                  row['created_at']?.toString() ?? row['updated_at'],
            );
            if (!_markHandled(key)) return;

            await show(
              title: 'Ajuan pembayaran baru',
              body: 'Ada penghuni yang mengirim ajuan pembayaran.',
            );

            _emit(
              NotificationSyncEvent(
                scope: 'owner_payments',
                table: 'payments',
                recordId: row['id']?.toString(),
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'payments',
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final kostId = row['kost_id']?.toString();
            if (kostId == null || !kostIds.contains(kostId)) return;

            final status = row['status']?.toString().toLowerCase() ?? '';
            if (status == 'pending') {
              final key = _realtimeKey(
                scope: 'owner_payment_update',
                row: row,
                rawDiscriminator:
                    '$status-${row['updated_at'] ?? row['created_at']}',
              );
              if (_markHandled(key)) {
                await show(
                  title: 'Ajuan pembayaran diperbarui',
                  body: 'Ada ajuan pembayaran yang perlu dicek owner.',
                );
              }
            }

            _emit(
              NotificationSyncEvent(
                scope: 'owner_payments',
                table: 'payments',
                recordId: row['id']?.toString(),
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  static void _attachOwnerExitRequestListener(Set<String> kostIds) {
    if (kostIds.isEmpty) return;

    final supabase = SupabaseService.client;
    final channel = supabase
        .channel('kostly-owner-profiles-${_activeRealtimeUserId ?? 'owner'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final kostId = row['kost_id']?.toString();
            if (kostId == null || !kostIds.contains(kostId)) return;
            if (!_isTruthy(row['exit_request'])) return;

            final key = _realtimeKey(
              scope: 'owner_exit_request',
              row: row,
              rawDiscriminator:
                  '${row['exit_request']}-${row['updated_at'] ?? row['kost_id']}',
            );
            if (!_markHandled(key)) return;

            await show(
              title: 'Permintaan keluar kost',
              body: 'Ada penghuni yang mengajukan keluar dari kost.',
            );

            _emit(
              NotificationSyncEvent(
                scope: 'owner_profiles',
                table: 'profiles',
                recordId: row['id']?.toString(),
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  static void _attachAdminOwnerApprovalListener() {
    final supabase = SupabaseService.client;
    final channel = supabase
        .channel('kostly-admin-profiles-${_activeRealtimeUserId ?? 'admin'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'profiles',
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (row['role']?.toString() != 'owner') return;
            if (_isTruthy(row['is_approved'])) return;

            final key = _realtimeKey(
              scope: 'admin_owner_insert',
              row: row,
              rawDiscriminator: row['created_at']?.toString(),
            );
            if (!_markHandled(key)) return;

            await show(
              title: 'Pendaftaran owner baru',
              body: 'Ada akun owner baru yang menunggu approval admin.',
            );

            _emit(
              NotificationSyncEvent(
                scope: 'admin_profiles',
                table: 'profiles',
                recordId: row['id']?.toString(),
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  static void _attachAdminKostApprovalListener() {
    final supabase = SupabaseService.client;
    final channel = supabase
        .channel('kostly-admin-kosts-${_activeRealtimeUserId ?? 'admin'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'kosts',
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (_isTruthy(row['is_approved'])) return;

            final key = _realtimeKey(
              scope: 'admin_kost_insert',
              row: row,
              rawDiscriminator: row['created_at']?.toString(),
            );
            if (!_markHandled(key)) return;

            await show(
              title: 'Unit kost baru',
              body: 'Ada unit kost baru yang menunggu approval admin.',
            );

            _emit(
              NotificationSyncEvent(
                scope: 'admin_kosts',
                table: 'kosts',
                recordId: row['id']?.toString(),
              ),
            );
          },
        )
        .subscribe();

    _channels.add(channel);
  }

  static void _emit(NotificationSyncEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  static bool _paymentBelongsToUser(
    Map<String, dynamic> payment,
    String userId,
  ) {
    final tenantId = payment['tenant_id']?.toString();
    final profileId = payment['profile_id']?.toString();
    return tenantId == userId || profileId == userId;
  }

  static (String, String)? _userPaymentNotification(String status) {
    switch (status) {
      case 'success':
      case 'approved':
      case 'paid':
        return (
          'Pembayaran disetujui',
          'Pembayaran kost kamu sudah disetujui owner.',
        );
      case 'rejected':
        return (
          'Pembayaran ditolak',
          'Pembayaran kost kamu ditolak. Silakan cek kembali.',
        );
      default:
        return null;
    }
  }

  static String _realtimeKey({
    required String scope,
    required Map<String, dynamic> row,
    required Object? rawDiscriminator,
  }) {
    return '$scope:${row['id']}:${rawDiscriminator ?? ''}';
  }

  static bool _markHandled(String key) {
    if (_handledRealtimeKeys.contains(key)) return false;
    _handledRealtimeKeys.add(key);
    if (_handledRealtimeKeys.length > 250) {
      _handledRealtimeKeys.remove(_handledRealtimeKeys.first);
    }
    return true;
  }

  static bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'y' ||
          normalized == 't';
    }
    return false;
  }
}
