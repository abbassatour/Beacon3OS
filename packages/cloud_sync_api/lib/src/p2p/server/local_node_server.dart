// packages/cloud_sync_api/lib/src/p2p/server/local_node_server.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;

import 'package:cloud_sync_api/src/p2p/models/p2p_message.dart';

/// جلسة المصادقة المعلقة بانتظار استجابة العميل لرمز التحدي
class _PendingAuthSession {
  _PendingAuthSession({
    required this.nonce,
    required this.timeoutTimer,
    required this.createdAt,
  });

  final String nonce;
  final Timer timeoutTimer;
  final DateTime createdAt;
}

/// خادم المقابس المحلي المؤمن بنظام التحدي والمصادقة الصفرية
/// (Zero-Trust Authenticated Local WebSocket Server)
/// يضمن عدم تسريب أي بيانات أو تنفيذ أي أمر إلا للأجهزة المصادق عليها.
class LocalNodeServer {
  LocalNodeServer({
    this.basePort = 8492,
    this.nodeId = 'beacon_host_display',
    this.authTimeout = const Duration(seconds: 5),
  });

  final int basePort;
  final String nodeId;
  final Duration authTimeout;

  int _activePort = 8492;
  HttpServer? _server;

  // 🔒 إدارة الهويات الأمنية المسموح لها بالاتصال
  String? _expectedVaultId;
  String? _expectedPairingCode;

  // 👥 قائمة العملاء الموثقين فقط
  final Set<WebSocket> _authenticatedClients = {};

  // ⏳ العملاء بانتظار إتمام المصادقة
  final Map<WebSocket, _PendingAuthSession> _pendingAuth = {};

  // 📥 تدفق الرسائل الموثقة الواردة فقط
  final StreamController<P2pMessage> _incomingMessagesController =
      StreamController<P2pMessage>.broadcast();

  Stream<P2pMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  int get port => _activePort;
  bool get isRunning => _server != null;
  int get clientCount => _authenticatedClients.length;
  int get pendingAuthCount => _pendingAuth.length;

  /// تحديث المعايير الأمنية المعتمدة (تحديث كود الاقتران أو معرف الخزنة المقترنة)
  void updateSecurityCredentials({
    String? linkedVaultId,
    String? pairingCode,
  }) {
    _expectedVaultId = linkedVaultId;
    _expectedPairingCode = pairingCode;
    log('LocalNodeServer: 🛡️ Security credentials updated -> VaultId: $_expectedVaultId, PairingCode: $_expectedPairingCode');
  }

  /// بدء تشغيل السيرفر مع ميزة تجربة المنافذ المتتالية تلقائياً (Port Auto-Increment)
  Future<int?> start() async {
    if (_server != null) return _activePort;

    for (var offset = 0; offset < 8; offset++) {
      final tryPort = basePort + offset;
      try {
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          tryPort,
          shared: true,
        );
        _activePort = tryPort;
        log('LocalNodeServer: 🚀 Secure Server running on ws://0.0.0.0:$_activePort/beacon_sync');
        _listenToRequests();
        return _activePort;
      } catch (e) {
        log('LocalNodeServer: Port $tryPort busy, trying next...');
      }
    }

    log('LocalNodeServer: ❌ Failed to bind to any port in range $basePort..${basePort + 7}');
    return null;
  }

  void _listenToRequests() {
    _server?.listen((HttpRequest request) async {
      if (request.uri.path == '/beacon_sync') {
        try {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleNewClient(socket);
        } catch (e) {
          log('LocalNodeServer: WebSocket upgrade error: $e');
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('BeaconOS Secure P2P Gateway Active')
          ..close();
      }
    });
  }

  /// معالجة العميل الجديد ببدء بروتوكول التحدي (Challenge Handshake)
  void _handleNewClient(WebSocket socket) {
    log('LocalNodeServer: 🟡 Peer connected. Initiating cryptographic challenge...');

    // 1. توليد رمز تحدٍ عشوائي مشفر لا يمكن التنبؤ به (Cryptographic Nonce)
    final rng = Random.secure();
    final nonceBytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final nonceHex = nonceBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // 2. ضبط مؤقت لقطع الاتصال إذا لم تتم المصادقة خلال المهلة المحددة
    final timeoutTimer = Timer(authTimeout, () {
      if (_pendingAuth.containsKey(socket)) {
        log('LocalNodeServer: ⏱️ Auth timeout reached. Disconnecting unverified peer.');
        _rejectAndClose(
          socket,
          reason: 'Authentication challenge timed out.',
        );
      }
    });

    _pendingAuth[socket] = _PendingAuthSession(
      nonce: nonceHex,
      timeoutTimer: timeoutTimer,
      createdAt: DateTime.now().toUtc(),
    );

    // 3. إرسال رمز التحدي للعميل
    final challenge = P2pMessage.create(
      type: P2pMessageType.authChallenge,
      payload: {
        'nonce': nonceHex,
        'server_id': nodeId,
        'server_time': DateTime.now().toUtc().toIso8601String(),
      },
      senderId: nodeId,
      senderType: 'server',
    );
    socket.add(challenge.encode());

    // 4. الاستماع الحصري لرسائل المصادقة
    socket.listen(
      (data) {
        if (data is String) {
          final message = P2pMessage.tryDecode(data);
          if (message != null) {
            _routeSocketMessage(socket, message);
          }
        }
      },
      onDone: () => _cleanSocket(socket),
      onError: (Object error) {
        log('LocalNodeServer: Socket error: $error');
        _cleanSocket(socket);
      },
      cancelOnError: true,
    );
  }

  /// توجيه وفحص الرسالة: هل المقبس مصادق عليه أم بانتظار الاعتماد؟
  void _routeSocketMessage(WebSocket socket, P2pMessage message) {
    // 🛡️ الحالة أ: المقبس غير مصادق عليه بعد
    if (_pendingAuth.containsKey(socket)) {
      if (message.type == P2pMessageType.authResponse) {
        _verifyAuthResponse(socket, message);
      } else {
        // حظر فوري: أي أمر آخر يحاول اختراق الخادم قبل إتمام المصادقة
        log('LocalNodeServer: 🚨 Security Alert! Blocked unauthorized command [${message.type.name}] from unauthenticated peer.');
        _rejectAndClose(
          socket,
          reason: 'Unauthorized command before auth completion.',
        );
      }
      return;
    }

    // 🛡️ الحالة ب: المقبس معتمد ومصرح له بالكامل
    if (_authenticatedClients.contains(socket)) {
      if (message.type == P2pMessageType.ping) {
        final pong = P2pMessage.create(
          type: P2pMessageType.pong,
          payload: {'reply_to': message.id},
          customId: 'pong_${message.id}',
          senderId: nodeId,
          senderType: 'server',
        );
        socket.add(pong.encode());
      } else {
        // تمرير الأمر الموثوق للمنظومة
        _incomingMessagesController.add(message);
      }
    }
  }

  /// التحقق الصارم من استجابة العميل لرمز التحدي
  void _verifyAuthResponse(WebSocket socket, P2pMessage message) {
    final session = _pendingAuth[socket];
    if (session == null) return;

    final clientNonce = message.payload['nonce'] as String?;
    final clientVaultId = message.payload['vault_id'] as String?;
    final clientPairingCode = message.payload['pairing_code'] as String?;

    // 1. التأكد من تطابق رمز التحدي لمنع هجمات إعادة الإرسال (Replay Attacks)
    if (clientNonce == null || clientNonce != session.nonce) {
      log('LocalNodeServer: ❌ Auth Failed: Nonce mismatch.');
      _rejectAndClose(socket, reason: 'Invalid or forged challenge nonce.');
      return;
    }

    var isAuthorized = false;
    String authReason = '';

    // 2. التحقق من كود الاقتران النشط حالياً على شاشة العرض
    if (_expectedPairingCode != null &&
        clientPairingCode != null &&
        clientPairingCode.trim() == _expectedPairingCode!.trim()) {
      isAuthorized = true;
      authReason = 'Pairing code matched';
    }

    // 3. التحقق من معرف الخزنة السيادية المعتمدة (DID)
    if (!isAuthorized &&
        _expectedVaultId != null &&
        clientVaultId != null &&
        clientVaultId.trim().toLowerCase() ==
            _expectedVaultId!.trim().toLowerCase()) {
      isAuthorized = true;
      authReason = 'Linked Sovereign Vault ID matched';
    }

    if (isAuthorized) {
      session.timeoutTimer.cancel();
      _pendingAuth.remove(socket);
      _authenticatedClients.add(socket);

      log('LocalNodeServer: 🟢 Peer authenticated successfully ($authReason). Total verified clients: ${_authenticatedClients.length}');

      final successMsg = P2pMessage.create(
        type: P2pMessageType.authSuccess,
        payload: {
          'server_id': nodeId,
          'status': 'authenticated',
          'message': 'Welcome to BeaconOS Sovereign Local Relay',
        },
        senderId: nodeId,
        senderType: 'server',
      );
      socket.add(successMsg.encode());
    } else {
      log('LocalNodeServer: ❌ Auth Failed: Credentials rejected. (ClientVault: $clientVaultId, ClientCode: $clientPairingCode)');
      _rejectAndClose(
        socket,
        reason: 'Credentials rejected. No active pairing or vault match.',
      );
    }
  }

  /// رفض الاتصال وإغلاق المقبس بحظر أمني صريح
  void _rejectAndClose(WebSocket socket, {required String reason}) {
    try {
      final failMsg = P2pMessage.create(
        type: P2pMessageType.authFailed,
        payload: {'reason': reason},
        senderId: nodeId,
        senderType: 'server',
      );
      socket.add(failMsg.encode());
    } catch (_) {}

    _cleanSocket(socket);
    try {
      socket.close(WebSocketStatus.policyViolation, reason);
    } catch (_) {}
  }

  /// بث رسالة للعملاء المعتمدين والمصادق عليهم فقط
  void broadcast(P2pMessage message) {
    if (_authenticatedClients.isEmpty) return;

    final encoded = message.encode();
    for (final client in _authenticatedClients) {
      try {
        if (client.readyState == WebSocket.open) {
          client.add(encoded);
        }
      } catch (e) {
        log('LocalNodeServer: Broadcast send error: $e');
      }
    }
  }

  /// إرسال رسالة مباشرة إلى عميل محدد إذا كان مصرحاً له
  bool sendTo(WebSocket socket, P2pMessage message) {
    if (_authenticatedClients.contains(socket) &&
        socket.readyState == WebSocket.open) {
      socket.add(message.encode());
      return true;
    }
    return false;
  }

  void _cleanSocket(WebSocket socket) {
    if (_pendingAuth.containsKey(socket)) {
      _pendingAuth[socket]?.timeoutTimer.cancel();
      _pendingAuth.remove(socket);
    }
    _authenticatedClients.remove(socket);
  }

  Future<void> stop() async {
    for (final session in _pendingAuth.values) {
      session.timeoutTimer.cancel();
    }
    _pendingAuth.clear();

    for (final client in _authenticatedClients) {
      await client.close(WebSocketStatus.normalClosure);
    }
    _authenticatedClients.clear();

    await _server?.close(force: true);
    _server = null;
    log('LocalNodeServer: Stopped.');
  }

  void dispose() {
    stop();
    _incomingMessagesController.close();
  }
}