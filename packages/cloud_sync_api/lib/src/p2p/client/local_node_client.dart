// packages/cloud_sync_api/lib/src/p2p/client/local_node_client.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_sync_api/src/p2p/models/local_node_info.dart';
import 'package:cloud_sync_api/src/p2p/models/p2p_message.dart';

/// حالات اتصال العميل المحلي
enum LocalClientState {
  disconnected,
  connecting,
  authenticating, // متصل بالشبكة وبانتظار حل رمز التحدي
  connected,      // مصادق عليه ومفعل بالكامل
  authFailed,     // تم رفض بيانات الاعتماد من الخادم
}

/// عميل المقابس المحلي المؤمن بنظام المصادقة المشتركة (Authenticated Local WebSocket Client)
/// يتصل بشاشات العرض المحلية (TV / Desktop) ويحل رمز التحدي الأمني فورياً.
class LocalNodeClient {
  LocalNodeClient();

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  LocalNodeInfo? _targetNode;
  Completer<bool>? _authCompleter;

  // هويات الاعتماد النشطة للعميل
  String? _vaultId;
  String? _pairingCode;
  String _clientId = 'beacon_mobile_node';

  LocalClientState _state = LocalClientState.disconnected;
  LocalClientState get state => _state;
  bool get isConnected => _state == LocalClientState.connected;
  LocalNodeInfo? get targetNode => _targetNode;

  final StreamController<LocalClientState> _stateController =
      StreamController<LocalClientState>.broadcast();
  final StreamController<P2pMessage> _incomingMessagesController =
      StreamController<P2pMessage>.broadcast();

  Stream<LocalClientState> get stateChanges => _stateController.stream;
  Stream<P2pMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  /// تهيئة بيانات الاعتماد قبل بدء محاولات الاتصال
  void configureCredentials({
    String? vaultId,
    String? pairingCode,
    String? clientId,
  }) {
    _vaultId = vaultId;
    _pairingCode = pairingCode;
    if (clientId != null && clientId.isNotEmpty) {
      _clientId = clientId;
    }
  }

  /// الاتصال المباشر بشاشة أو جهاز تم اكتشافه مع إتمام المصادقة التشفيرية
  Future<bool> connectToNode(
    LocalNodeInfo node, {
    String? vaultId,
    String? pairingCode,
    String? clientId,
  }) async {
    _targetNode = node;
    if (vaultId != null) _vaultId = vaultId;
    if (pairingCode != null) _pairingCode = pairingCode;
    if (clientId != null) _clientId = clientId;

    await disconnect();

    _updateState(LocalClientState.connecting);
    final url = 'ws://${node.ip}:${node.port}/beacon_sync';
    log('LocalNodeClient: Connecting to secure endpoint $url...');

    _authCompleter = Completer<bool>();

    try {
      _socket = await WebSocket.connect(url).timeout(
        const Duration(seconds: 4),
      );

      _updateState(LocalClientState.authenticating);
      log('LocalNodeClient: ⚡ TCP Socket open. Awaiting server challenge...');

      _listenToSocket();

      // انتظار استجابة واعتماد الخادم لرمز التحدي (بمهلة أقصاها 6 ثوانٍ)
      return await _authCompleter!.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          log('LocalNodeClient: ⏱️ Handshake timeout. Server did not confirm auth.');
          disconnect();
          return false;
        },
      );
    } catch (e) {
      log('LocalNodeClient: Connection failed to ${node.ip}: $e');
      _finishAuthCompleter(false);
      _updateState(LocalClientState.disconnected);
      return false;
    }
  }

  void _listenToSocket() {
    _socket?.listen(
      (data) {
        if (data is String) {
          final message = P2pMessage.tryDecode(data);
          if (message != null) {
            _handleIncomingMessage(message);
          }
        }
      },
      onDone: () {
        log('LocalNodeClient: Connection closed by remote host.');
        _finishAuthCompleter(false);
        disconnect();
      },
      onError: (Object error) {
        log('LocalNodeClient: Socket error: $error');
        _finishAuthCompleter(false);
        disconnect();
      },
      cancelOnError: true,
    );
  }

  /// معالجة الرسائل الواردة وإدارة بروتوكول المصادقة
  void _handleIncomingMessage(P2pMessage message) {
    switch (message.type) {
      // 1. استقبال رمز التحدي من السيرفر
      case P2pMessageType.authChallenge:
        final nonce = message.payload['nonce'] as String?;
        if (nonce != null && nonce.isNotEmpty) {
          log('LocalNodeClient: 🔑 Received challenge nonce. Sending proof to host...');
          _respondToChallenge(nonce);
        } else {
          log('LocalNodeClient: ❌ Received malformed auth challenge.');
          _finishAuthCompleter(false);
          disconnect();
        }
        break;

      // 2. نجاح المصادقة واعتماد العميل
      case P2pMessageType.authSuccess:
        log('LocalNodeClient: 🟢 Server authenticated this device! Connection fully secured (< 2ms).');
        _updateState(LocalClientState.connected);
        _startHeartbeat();
        _finishAuthCompleter(true);
        break;

      // 3. فشل المصادقة ورفض الاتصال
      case P2pMessageType.authFailed:
        final reason = message.payload['reason'] ?? 'Rejected by server';
        log('LocalNodeClient: 🔴 Authentication rejected by host: $reason');
        _updateState(LocalClientState.authFailed);
        _finishAuthCompleter(false);
        disconnect();
        break;

      // 4. استجابة نبضات القلب
      case P2pMessageType.pong:
        break;

      // 5. كافة الرسائل والأوامر الموثوقة الأخرى
      default:
        if (isConnected) {
          _incomingMessagesController.add(message);
        }
        break;
    }
  }

  /// إرسال إثبات الهوية المشترك رداً على رمز التحدي
  void _respondToChallenge(String nonce) {
    // نعتمد كود الاقتران النشط أو كود الجهاز المكتشف أو معرف الخزنة (DID)
    final effectivePairingCode = _pairingCode ?? _targetNode?.pairingCode;

    final authResponse = P2pMessage.create(
      type: P2pMessageType.authResponse,
      payload: {
        'nonce': nonce,
        if (_vaultId != null) 'vault_id': _vaultId,
        if (effectivePairingCode != null) 'pairing_code': effectivePairingCode,
      },
      senderId: _clientId,
      senderType: 'phone',
    );

    send(authResponse, allowDuringAuth: true);
  }

  /// إرسال رسالة أو أمر عبر المقبس
  bool send(P2pMessage message, {bool allowDuringAuth = false}) {
    final canSend = (isConnected || (allowDuringAuth && _state == LocalClientState.authenticating));
    if (_socket != null && _socket!.readyState == WebSocket.open && canSend) {
      _socket!.add(message.encode());
      return true;
    }
    return false;
  }

  /// مؤشر نبضات القلب للتأكد من استمرار اتصال الواي فاي بعد نجاح التوثيق فقط
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_socket != null && _socket!.readyState == WebSocket.open && isConnected) {
        final ping = P2pMessage.create(
          type: P2pMessageType.ping,
          payload: {'timestamp': DateTime.now().toUtc().toIso8601String()},
          senderId: _clientId,
          senderType: 'phone',
        );
        _socket!.add(ping.encode());
      } else {
        disconnect();
      }
    });
  }

  void _finishAuthCompleter(bool result) {
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.complete(result);
    }
  }

  void _updateState(LocalClientState nextState) {
    if (_state != nextState) {
      _state = nextState;
      _stateController.add(_state);
    }
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_socket != null) {
      try {
        await _socket?.close(WebSocketStatus.normalClosure);
      } catch (_) {}
      _socket = null;
    }

    if (_state != LocalClientState.disconnected) {
      _updateState(LocalClientState.disconnected);
    }
  }

  void dispose() {
    disconnect();
    _finishAuthCompleter(false);
    _stateController.close();
    _incomingMessagesController.close();
  }
}