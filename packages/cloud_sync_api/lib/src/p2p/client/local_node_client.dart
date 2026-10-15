import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_sync_api/src/p2p/models/local_node_info.dart';
import 'package:cloud_sync_api/src/p2p/models/p2p_message.dart';

enum LocalClientState { disconnected, connecting, connected }

/// عميل المقابس المحلي الفائق السرعة (Local WebSocket Client)
class LocalNodeClient {
  LocalNodeClient();

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  LocalNodeInfo? _targetNode;

  LocalClientState _state = LocalClientState.disconnected;
  LocalClientState get state => _state;
  bool get isConnected => _state == LocalClientState.connected;

  final StreamController<LocalClientState> _stateController =
      StreamController<LocalClientState>.broadcast();
  final StreamController<P2pMessage> _incomingMessagesController =
      StreamController<P2pMessage>.broadcast();

  Stream<LocalClientState> get stateChanges => _stateController.stream;
  Stream<P2pMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  /// الاتصال المباشر بشاشة أو جهاز تم اكتشافه على الشبكة
  Future<bool> connectToNode(LocalNodeInfo node) async {
    _targetNode = node;
    await disconnect();

    _updateState(LocalClientState.connecting);
    final url = 'ws://${node.ip}:${node.port}/beacon_sync';
    log('LocalNodeClient: Connecting to $url...');

    try {
      _socket = await WebSocket.connect(url).timeout(
        const Duration(seconds: 3),
      );

      _updateState(LocalClientState.connected);
      log('LocalNodeClient: ⚡ Connected directly to ${node.deviceType} on LAN (< 2ms)!');

      _startHeartbeat();
      _listenToSocket();
      return true;
    } catch (e) {
      log('LocalNodeClient: Connection failed to ${node.ip}: $e');
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
            _incomingMessagesController.add(message);
          }
        }
      },
      onDone: () {
        log('LocalNodeClient: Connection closed by remote peer.');
        disconnect();
      },
      onError: (Object error) {
        log('LocalNodeClient: Socket error: $error');
        disconnect();
      },
      cancelOnError: true,
    );
  }

  /// إرسال أمر أو رسالة بسرعة البرق عبر المقبس
  bool send(P2pMessage message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(message.encode());
      return true;
    }
    return false;
  }

  /// مؤشر نبضات القلب للتأكد من استمرار اتصال الواي فاي المحلي كل 3 ثوانٍ
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_socket != null && _socket!.readyState == WebSocket.open) {
        final ping = P2pMessage.create(
          type: P2pMessageType.ping,
          payload: {'timestamp': DateTime.now().toIso8601String()},
        );
        _socket!.add(ping.encode());
      } else {
        disconnect();
      }
    });
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

    _updateState(LocalClientState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _incomingMessagesController.close();
  }
}