import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_sync_api/src/p2p/models/p2p_message.dart';

/// خادم المقابس المحلي المدمج (Embedded Local WebSocket Server)
/// تم ضبط توقيت مصافحة الخادم ليعتمد التوقيت العالمي الموحد (UTC).
class LocalNodeServer {
  LocalNodeServer({this.basePort = 8492});

  final int basePort;
  int _activePort = 8492;
  HttpServer? _server;

  final Set<WebSocket> _connectedClients = {};
  final StreamController<P2pMessage> _incomingMessagesController =
      StreamController<P2pMessage>.broadcast();

  Stream<P2pMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  int get port => _activePort;
  bool get isRunning => _server != null;
  int get clientCount => _connectedClients.length;

  /// بدء تشغيل السيرفر مع ميزة المنافذ المرنة (Port Auto-Increment)
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
        log('LocalNodeServer: 🚀 Running on ws://0.0.0.0:$_activePort/beacon_sync');
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
          ..write('BeaconOS Local Sync Server Active')
          ..close();
      }
    });
  }

  void _handleNewClient(WebSocket socket) {
    _connectedClients.add(socket);
    log('LocalNodeServer: 🟢 New peer connected. Total clients: ${_connectedClients.length}');

    final welcome = P2pMessage.create(
      type: P2pMessageType.handshake,
      payload: {
        'status': 'accepted',
        'server_time': DateTime.now().toUtc().toIso8601String(),
      },
      senderType: 'server',
    );
    socket.add(welcome.encode());

    socket.listen(
      (data) {
        if (data is String) {
          final message = P2pMessage.tryDecode(data);
          if (message != null) {
            if (message.type == P2pMessageType.ping) {
              final pong = P2pMessage.create(
                type: P2pMessageType.pong,
                payload: {'reply_to': message.id},
                customId: 'pong_${message.id}',
              );
              socket.add(pong.encode());
            } else {
              _incomingMessagesController.add(message);
            }
          }
        }
      },
      onDone: () {
        _connectedClients.remove(socket);
        log('LocalNodeServer: 🔴 Peer disconnected. Total clients: ${_connectedClients.length}');
      },
      onError: (Object error) {
        _connectedClients.remove(socket);
        log('LocalNodeServer: Socket error: $error');
      },
      cancelOnError: true,
    );
  }

  /// بث رسالة لجميع العملاء المتصلين في نفس اللحظة
  void broadcast(P2pMessage message) {
    if (_connectedClients.isEmpty) return;

    final encoded = message.encode();
    for (final client in _connectedClients) {
      try {
        if (client.readyState == WebSocket.open) {
          client.add(encoded);
        }
      } catch (e) {
        log('LocalNodeServer: Broadcast send error: $e');
      }
    }
  }

  Future<void> stop() async {
    for (final client in _connectedClients) {
      await client.close(WebSocketStatus.normalClosure);
    }
    _connectedClients.clear();
    await _server?.close(force: true);
    _server = null;
    log('LocalNodeServer: Stopped.');
  }

  void dispose() {
    stop();
    _incomingMessagesController.close();
  }
}