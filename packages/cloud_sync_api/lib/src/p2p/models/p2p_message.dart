// packages/cloud_sync_api/lib/src/p2p/models/p2p_message.dart
import 'dart:convert';
import 'dart:developer';

/// أنواع الرسائل المتبادلة محلياً بين أجهزة BeaconOS
enum P2pMessageType {
  ping,
  pong,
  handshake,
  
  // 🔐 بروتوكول المصادقة التشفيري (Zero-Trust Local Authentication)
  authChallenge,     // الخادم يرسل رمز تحدي عشوائي (Nonce) فور فتح المقبس
  authResponse,      // العميل يرسل إثبات الهوية المشفر بناءً على المعرف المشترك
  authSuccess,       // اعتماد الاتصال وتفعيل الصلاحيات الكاملة
  authFailed,        // رفض الاتصال وإغلاق المقبس
  
  // ⚡ الأوامر التنفيذية الحية
  locateDevice,
  triggerSos,
  vaultMutation,
  telemetry,
  devicePairing,
  
  // 🔄 بروتوكول المزامنة التفاضلية الذكية (Delta Sync Protocol)
  vaultDeltaRequest,  // طلب العناصر المعدلة بعد تاريخ معين فقط (Since UTC)
  vaultDeltaResponse, // إرجاع السجلات المضافة والمعدلة والمحذوفة فقط
  vaultSyncRequest,   // طلب لقطة كاملة (يستخدم فقط عند أول اقتران)
  vaultSyncResponse,  // إرجاع لقطة كاملة
  
  unknown,
}

/// كبسولة الرسائل المحلية الموحدة والآمنة (Self-Contained & Authenticated P2P Message Envelope)
/// تم ضبط كافة طوابع التوقيت الزمنية لتعمل حصرياً بالتوقيت العالمي الموحد (UTC).
class P2pMessage {
  const P2pMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.senderId,
    this.senderType,
    this.authSignature,
  });

  /// المعرف الفريد للرسالة لمنع التكرار (Deduplication)
  final String id;
  
  /// نوع الرسالة الإجرائية
  final P2pMessageType type;
  
  /// محتوى البيانات المشفر أو المنقول
  final Map<String, dynamic> payload;
  
  /// الطابع الزمني الموحد بالـ UTC
  final DateTime timestamp;
  
  /// معرف العقدة المرسلة
  final String? senderId;
  
  /// نوع جهاز المرسل (phone, fire_tv, desktop)
  final String? senderType;

  /// توقيع أو رمز التحقق المشتق من المعرف السيادي المشترك (إن وجد)
  final String? authSignature;

  /// منشئ مخصص لإنشاء رسائل جديدة مع توليد تلقائي للمعرف والوقت
  factory P2pMessage.create({
    required P2pMessageType type,
    required Map<String, dynamic> payload,
    String? senderId,
    String? senderType,
    String? authSignature,
    String? customId,
  }) {
    final nowUtc = DateTime.now().toUtc();
    return P2pMessage(
      id: customId ?? '${nowUtc.microsecondsSinceEpoch}_${type.name}',
      type: type,
      payload: payload,
      timestamp: nowUtc,
      senderId: senderId,
      senderType: senderType,
      authSignature: authSignature,
    );
  }

  /// تحويل كائن JSON القادم من الشبكة إلى رسالة P2pMessage محمية
  factory P2pMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    final p2pType = P2pMessageType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      orElse: () => P2pMessageType.unknown,
    );

    DateTime parsedTimestamp = DateTime.now().toUtc();
    if (json['timestamp'] != null) {
      final parsed = DateTime.tryParse(json['timestamp'] as String);
      if (parsed != null) {
        parsedTimestamp = parsed.toUtc();
      }
    }

    return P2pMessage(
      id: json['id'] as String? ?? '${DateTime.now().toUtc().millisecondsSinceEpoch}',
      type: p2pType,
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
      timestamp: parsedTimestamp,
      senderId: json['sender_id'] as String?,
      senderType: json['sender_type'] as String?,
      authSignature: json['auth_signature'] as String?,
    );
  }

  /// تحويل الرسالة إلى كائن JSON للإرسال عبر مقبس الشبكة
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (senderId != null) 'sender_id': senderId,
      if (senderType != null) 'sender_type': senderType,
      if (authSignature != null) 'auth_signature': authSignature,
    };
  }

  /// ترميز الرسالة إلى نص JSON جاهز للنقل
  String encode() => jsonEncode(toJson());

  /// محاولة فك ترميز النص الوارد بأمان مع حماية من انهيار التطبيق
  static P2pMessage? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return P2pMessage.fromJson(decoded);
      }
    } catch (e) {
      log('LocalP2pClient: Failed to decode message envelope: $e');
    }
    return null;
  }

  @override
  String toString() =>
      'P2pMessage(id: $id, type: ${type.name}, sender: $senderType/$senderId, time: ${timestamp.toIso8601String()})';
}