// packages/cloud_sync_api/lib/src/cloud_sync_client.dart
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

/// عميل المزامنة السحابية وبث الرادار لمنظومة BeaconOS عبر Supabase.
/// يدعم معمارية UUID والحذف الناعم والدفع الجماعي (Batch Operations) والبث اللحظي (Realtime Streams).
class CloudSyncClient {
  CloudSyncClient();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // 🔐 1. المصادقة وإدارة الجلسة (Auth & Session Management)
  // ===========================================================================

  User? get currentUser => _client?.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String get activeUserId => currentUser?.id ?? 'local_guest_user';
  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  Future<AuthResponse?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client?.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      log('CloudSyncClient: User signed in (${response?.user?.id})');
      return response;
    } catch (e, st) {
      log('CloudSyncClient: Sign in error: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client?.auth.signUp(
        email: email.trim(),
        password: password,
      );
      log('CloudSyncClient: Account created (${response?.user?.id})');
      return response;
    } catch (e, st) {
      log('CloudSyncClient: Sign up error: $e', stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse?> signInAnonymously() async {
    try {
      final response = await _client?.auth.signInAnonymously();
      log('CloudSyncClient: Anonymous session active.');
      return response;
    } catch (e) {
      log('CloudSyncClient: Anonymous sign-in bypassed (Offline Mode): $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
      log('CloudSyncClient: Signed out successfully.');
    } catch (e) {
      log('CloudSyncClient: Sign out error: $e');
    }
  }

  // ===========================================================================
  // ⚙️ 2. مزامنة الإعدادات الشاملة (App Settings Sync)
  // ===========================================================================

  Future<void> syncSettings(Map<String, dynamic> settingsData) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      final payload = Map<String, dynamic>.from(settingsData)..['user_id'] = userId;
      await client.from('app_settings').upsert(payload);
      log('CloudSyncClient: Settings synced to cloud.');
    } catch (e) {
      log('CloudSyncClient: Settings sync skipped/failed: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchCloudSettings() async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return null;

    try {
      final res = await client
          .from('app_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return res;
    } catch (e) {
      log('CloudSyncClient: Failed to fetch cloud settings: $e');
      return null;
    }
  }

  // ===========================================================================
  // 📇 3. جهات الاتصال ورادار الطوارئ (Contacts - Complete with Batch Sync & Streams)
  // ===========================================================================

  Future<void> syncContact({
    required String id,
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
    DateTime? deletedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('contacts').upsert({
        'id': id,
        'user_id': userId,
        'name': name.trim(),
        'phone_number': phoneNumber.trim(),
        'relationship': relationship?.trim(),
        'is_emergency': isEmergency,
        'deleted_at': deletedAt?.toIso8601String(),
      });
      log('CloudSyncClient: Contact synced to cloud: $name');
    } catch (e) {
      log('CloudSyncClient: Contact cloud sync skipped: $e');
    }
  }

  /// ⚡ مزامنة دفعة كاملة من جهات الاتصال في طلب شبكي واحد (Batch Upsert)
  Future<void> syncContactsBatch(List<Map<String, dynamic>> contactsList) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null || contactsList.isEmpty) return;

    try {
      final payload = contactsList.map((contact) {
        return {
          ...contact,
          'user_id': userId,
        };
      }).toList();

      await client.from('contacts').upsert(payload);
      log('CloudSyncClient: ⚡ Batch synced ${payload.length} contacts to cloud successfully.');
    } catch (e, st) {
      log('CloudSyncClient: Batch contact sync skipped/failed: $e', stackTrace: st);
    }
  }

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return [];

    try {
      final response = await client
          .from('contacts')
          .select()
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      log('CloudSyncClient: Failed to fetch contacts: $e', stackTrace: st);
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>>? streamContacts() {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return null;

    return client
        .from('contacts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('name', ascending: true);
  }

  Future<void> softDeleteContactInCloud(String contactId) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('contacts').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', contactId).eq('user_id', userId);
    } catch (e) {
      log('CloudSyncClient: Failed to soft delete contact: $e');
    }
  }

  /// ⚡ حذف ناعم دفعة واحدة في السحابة لمجموعة معرفات
  Future<void> softDeleteContactsBatchInCloud(List<String> contactIds) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null || contactIds.isEmpty) return;

    try {
      await client.from('contacts').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).inFilter('id', contactIds).eq('user_id', userId);
      log('CloudSyncClient: ⚡ Batch soft-deleted ${contactIds.length} contacts in cloud.');
    } catch (e) {
      log('CloudSyncClient: Failed to batch soft delete contacts: $e');
    }
  }

  Future<void> hardDeleteContact(String contactId) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client
          .from('contacts')
          .delete()
          .eq('id', contactId)
          .eq('user_id', userId);
    } catch (e) {
      log('CloudSyncClient: Failed to hard delete contact: $e');
    }
  }

  // ===========================================================================
  // 💬 4. سجل التراسل الصامت (Messages Vault)
  // ===========================================================================

  Future<void> syncMessage({
    required String id,
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
    DateTime? timestamp,
    bool isRead = false,
    DateTime? deletedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('messages_vault').upsert({
        'id': id,
        'user_id': userId,
        'contact_identifier': contactIdentifier.trim(),
        'sender_name': senderName.trim(),
        'message_text': messageText.trim(),
        'platform': platform.toLowerCase(),
        'is_outgoing': isOutgoing,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
        'is_read': isRead,
        'deleted_at': deletedAt?.toIso8601String(),
      });
      log('CloudSyncClient: Message logged in cloud ($platform: $senderName)');
    } catch (e) {
      log('CloudSyncClient: Message vault sync skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentMessages({int limit = 50}) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return [];

    try {
      final response = await client
          .from('messages_vault')
          .select()
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .order('timestamp', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      log('CloudSyncClient: Failed to fetch messages: $e', stackTrace: st);
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>>? streamMessages() {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return null;

    return client
        .from('messages_vault')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('timestamp', ascending: true);
  }

  Future<void> markMessagesAsReadInCloud(String contactIdentifier) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client
          .from('messages_vault')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('contact_identifier', contactIdentifier);
    } catch (e) {
      log('CloudSyncClient: Mark messages as read skipped: $e');
    }
  }

  // ===========================================================================
  // 📋 5. المهام والأجندة (Tasks Sync with Streams)
  // ===========================================================================

  Future<void> syncTask({
    required String id,
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
    bool isCompleted = false,
    DateTime? deletedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('tasks').upsert({
        'id': id,
        'user_id': userId,
        'title': title.trim(),
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'is_completed': isCompleted,
        'deleted_at': deletedAt?.toIso8601String(),
      });
      log('CloudSyncClient: Task synced: $title');
    } catch (e) {
      log('CloudSyncClient: Task sync skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTasks() async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return [];

    try {
      final response = await client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .order('due_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>>? streamTasks() {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return null;

    return client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('due_date', ascending: true);
  }

  Future<void> softDeleteTaskInCloud(String taskId) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('tasks').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId).eq('user_id', userId);
    } catch (e) {
      log('CloudSyncClient: Soft delete task error: $e');
    }
  }

  // ===========================================================================
  // 🎙️ 6. المذكرات الصوتية (Voice Memos Sync with Streams)
  // ===========================================================================

  Future<void> syncMemo({
    required String id,
    required String title,
    required String content,
    DateTime? deletedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('voice_memos').upsert({
        'id': id,
        'user_id': userId,
        'title': title.trim(),
        'content': content.trim(),
        'deleted_at': deletedAt?.toIso8601String(),
      });
      log('CloudSyncClient: Memo synced: $title');
    } catch (e) {
      log('CloudSyncClient: Memo sync skipped: $e');
    }
  }

  Stream<List<Map<String, dynamic>>>? streamMemos() {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return null;

    return client
        .from('voice_memos')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> softDeleteMemoInCloud(String memoId) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('voice_memos').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', memoId).eq('user_id', userId);
    } catch (e) {
      log('CloudSyncClient: Soft delete memo error: $e');
    }
  }

  // ===========================================================================
  // ⏰ 7. المنبهات وجلسات التركيز (Alarms & Focus Sync)
  // ===========================================================================

  Future<void> syncAlarm({
    required String id,
    required int hour,
    required int minute,
    required String label,
    bool isActive = true,
    String daysOfWeek = 'daily',
    DateTime? deletedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('alarms').upsert({
        'id': id,
        'user_id': userId,
        'hour': hour,
        'minute': minute,
        'label': label.trim(),
        'days_of_week': daysOfWeek,
        'is_active': isActive,
        'deleted_at': deletedAt?.toIso8601String(),
      });
      log('CloudSyncClient: Alarm synced: $hour:$minute');
    } catch (e) {
      log('CloudSyncClient: Alarm sync skipped: $e');
    }
  }

  Future<void> softDeleteAlarmInCloud(String alarmId) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('alarms').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', alarmId).eq('user_id', userId);
    } catch (e) {
      log('CloudSyncClient: Soft delete alarm error: $e');
    }
  }

  Future<void> syncFocusSession({
    required String id,
    required int durationMinutes,
    String sessionType = 'study',
    DateTime? completedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('focus_sessions').upsert({
        'id': id,
        'user_id': userId,
        'duration_minutes': durationMinutes,
        'session_type': sessionType,
        'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
      });
      log('CloudSyncClient: Focus session logged ($durationMinutes mins)');
    } catch (e) {
      log('CloudSyncClient: Focus session sync skipped: $e');
    }
  }

  // ===========================================================================
  // 🚨 8. رادار الاستغاثة والطوارئ (SOS Radar Sync)
  // ===========================================================================

  Future<bool> broadcastEmergencySos({
    required String id,
    required double latitude,
    required double longitude,
    int batteryLevel = 100,
    String status = 'active',
  }) async {
    final client = _client;
    final userId = currentUser?.id ?? 'guest_offline_user';
    if (client == null) return false;

    try {
      final googleMapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';
      await client.from('sos_alerts').insert({
        'id': id,
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'battery_level': batteryLevel,
        'status': status,
        'google_maps_url': googleMapsUrl,
        'triggered_at': DateTime.now().toIso8601String(),
      });

      log('CloudSyncClient: Emergency SOS alert broadcasted to cloud radar.');
      return true;
    } catch (e, st) {
      log('CloudSyncClient: Failed to broadcast SOS: $e', stackTrace: st);
      return false;
    }
  }

  // ===========================================================================
  // 👁️ 9. الفحوصات البصرية الذكية (Vision Scans Sync)
  // ===========================================================================

  Future<void> syncVisionScan({
    required String id,
    required String mode,
    required String prompt,
    required String description,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('vision_scans').upsert({
        'id': id,
        'user_id': userId,
        'mode': mode,
        'prompt': prompt,
        'description': description,
      });
      log('CloudSyncClient: Vision scan backed up.');
    } catch (e) {
      log('CloudSyncClient: Vision scan sync skipped: $e');
    }
  }

  // ===========================================================================
  // 🧭 10. العُقد المكانية والشبكة الفضائية (Spatial Nodes & Topology Sync)
  // ===========================================================================

  Future<void> syncSpatialNode({
    required String id,
    required String moduleId,
    required int floorLevel,
    required int x,
    required int y,
    String? customTitle,
    String? configJson,
    bool isVisible = true,
    DateTime? deletedAt,
  }) async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await client.from('spatial_nodes').upsert({
        'id': id,
        'user_id': userId,
        'module_id': moduleId,
        'floor_level': floorLevel,
        'x': x,
        'y': y,
        'custom_title': customTitle,
        'config_json': configJson,
        'is_visible': isVisible,
        'deleted_at': deletedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      log('CloudSyncClient: Spatial node synced [$id -> ($x, $y, F$floorLevel)]');
    } catch (e) {
      log('CloudSyncClient: Spatial node sync skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSpatialNodes() async {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return [];

    try {
      final response = await client
          .from('spatial_nodes')
          .select()
          .eq('user_id', userId)
          .filter('deleted_at', 'is', null)
          .order('floor_level', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      log('CloudSyncClient: Failed to fetch spatial nodes: $e', stackTrace: st);
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>>? streamSpatialNodes() {
    final client = _client;
    final userId = currentUser?.id;
    if (client == null || userId == null) return null;

    return client
        .from('spatial_nodes')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('floor_level', ascending: true);
  }
}