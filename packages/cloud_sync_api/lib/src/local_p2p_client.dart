// packages/cloud_sync_api/lib/src/local_p2p_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

/// ============================================================================
/// 🏷️ 1. كبسولة الرسائل المحلية (Self-Contained P2P Message Envelope)
/// ============================================================================

/// أنواع الرسائل المتبادلة محلياً بين أجهزة BeaconOS
enum P2pMessageType {
  ping,
  pong,
  handshake,
  locateDevice,
  triggerSos,
  vaultMutation,
  telemetry,
  devicePairing,
  unknown,
}

class P2pMessage {
  const P2pMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.senderId,
    this.senderType,
  });

  /// المعرف الفريد للرسالة لمنع التكرار (Deduplication)
  final String id;
  final P2pMessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final String? senderId;
  final String? senderType;

  factory P2pMessage.create({
    required P2pMessageType type,
    required Map<String, dynamic> payload,
    String? senderId,
    String? senderType,
    String? customId,
  }) {
    return P2pMessage(
      id: customId ?? '${DateTime.now().microsecondsSinceEpoch}_${type.name}',
      type: type,
      payload: payload,
      timestamp: DateTime.now(),
      senderId: senderId,
      senderType: senderType,
    );
  }

  factory P2pMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    final p2pType = P2pMessageType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
      orElse: () => P2pMessageType.unknown,
    );

    return P2pMessage(
      id: json['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
      type: p2pType,
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : <String, dynamic>{},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      senderId: json['sender_id'] as String?,
      senderType: json['sender_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      if (senderId != null) 'sender_id': senderId,
      if (senderType != null) 'sender_type': senderType,
    };
  }

  String encode() => jsonEncode(toJson());

  static P2pMessage? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return P2pMessage.fromJson(decoded);
      }
    } catch (e) {
      log('LocalP2pClient: Failed to decode message: $e');
    }
    return null;
  }
}

/// ============================================================================
/// 🧭 2. معلومات العقدة المكتشفة في الشبكة (Local Node Descriptor)
/// ============================================================================

class LocalNodeInfo {
  const LocalNodeInfo({
    required this.nodeId,
    required this.deviceType,
    required this.ip,
    required this.port,
    this.pairingCode,
    this.vaultId,
    required this.lastSeen,
  });

  final String nodeId;
  final String deviceType; // 'fire_tv', 'desktop', 'phone'
  final String ip;
  final int port;
  final String? pairingCode;
  final String? vaultId;
  final DateTime lastSeen;

  factory LocalNodeInfo.fromJson(Map<String, dynamic> json, String fallbackIp) {
    return LocalNodeInfo(
      nodeId: json['node_id'] as String? ?? 'unknown_node',
      deviceType: json['device_type'] as String? ?? 'display',
      ip: (json['ip'] as String?)?.isNotEmpty == true
          ? json['ip'] as String
          : fallbackIp,
      port: (json['port'] as num?)?.toInt() ?? 8492,
      pairingCode: json['pairing_code'] as String?,
      vaultId: json['vault_id'] as String?,
      lastSeen: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'device_type': deviceType,
      'ip': ip,
      'port': port,
      if (pairingCode != null) 'pairing_code': pairingCode,
      if (vaultId != null) 'vault_id': vaultId,
    };
  }

  @override
  String toString() =>
      'LocalNodeInfo($deviceType @ $ip:$port, code: $pairingCode)';
}

/// ============================================================================
/// 📡 3. محرك الاستكشاف المحلي الصامت عبر UDP (Zero-Config UDP Discovery)
/// ============================================================================

class LocalNodeDiscovery {
  LocalNodeDiscovery({this.discoveryPort = 8491});

  final int discoveryPort;
  static const String discoveryProtocol = 'BEACON_P2P_DISCOVERY_V1';

  RawDatagramSocket? _socket;
  Timer? _advertisementTimer;
  final StreamController<LocalNodeInfo> _discoveredNodesController =
      StreamController<LocalNodeInfo>.broadcast();

  Stream<LocalNodeInfo> get discoveredNodes =>
      _discoveredNodesController.stream;

  bool get isActive => _socket != null;

  /// تهيئة مقبس الـ UDP للاستماع والإرسال
  Future<bool> initialize() async {
    if (_socket != null) return true;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;

      _socket!.listen(_handleIncomingDatagram, onError: (Object err) {
        log('LocalNodeDiscovery: Socket error: $err');
      });

      log('LocalNodeDiscovery: Bound to UDP port $discoveryPort successfully.');
      return true;
    } catch (e, st) {
      log('LocalNodeDiscovery: Failed to bind UDP socket: $e', stackTrace: st);
      return false;
    }
  }

  /// إعلان الشاشة (TV/Desktop) عن وجودها بانتظام وعند طلب الاستكشاف
  void startAdvertising({
    required String nodeId,
    required String deviceType,
    required int listeningPort,
    String? pairingCode,
    String? vaultId,
    Duration interval = const Duration(seconds: 4),
  }) {
    _advertisementTimer?.cancel();
    _advertisementTimer = Timer.periodic(interval, (_) {
      broadcastPresence(
        nodeId: nodeId,
        deviceType: deviceType,
        listeningPort: listeningPort,
        pairingCode: pairingCode,
        vaultId: vaultId,
      );
    });

    // إرسال إعلان أولي فوراً
    broadcastPresence(
      nodeId: nodeId,
      deviceType: deviceType,
      listeningPort: listeningPort,
      pairingCode: pairingCode,
      vaultId: vaultId,
    );
  }

  /// إرسال حزمة الإعلان عن الوجود
  Future<void> broadcastPresence({
    required String nodeId,
    required String deviceType,
    required int listeningPort,
    String? pairingCode,
    String? vaultId,
  }) async {
    if (_socket == null) {
      final ok = await initialize();
      if (!ok) return;
    }

    final payload = jsonEncode({
      'protocol': discoveryProtocol,
      'action': 'ANNOUNCE_PRESENCE',
      'node_id': nodeId,
      'device_type': deviceType,
      'port': listeningPort,
      'pairing_code': pairingCode,
      'vault_id': vaultId,
    });

    final bytes = utf8.encode(payload);
    await _sendToBroadcastAddresses(bytes);
  }

  /// إرسال نداء استكشاف فوري من الهاتف للبحث عن أي شاشة في الشبكة
  Future<void> probeForNodes() async {
    if (_socket == null) {
      final ok = await initialize();
      if (!ok) return;
    }

    final payload = jsonEncode({
      'protocol': discoveryProtocol,
      'action': 'DISCOVER_NODES',
      'timestamp': DateTime.now().toIso8601String(),
    });

    final bytes = utf8.encode(payload);
    await _sendToBroadcastAddresses(bytes);
    log('LocalNodeDiscovery: 🔍 Sent discovery probe on local network.');
  }

  /// إرسال الحزمة للبث العام وعناوين الشبكات الفرعية (Subnet Broadcasts)
  Future<void> _sendToBroadcastAddresses(List<int> bytes) async {
    if (_socket == null) return;

    try {
      // 1. البث العام القياسي
      _socket!.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);

      // 2. البث على كل كرت شبكة متصل لتفادي حظر الراوترات
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            // صياغة عنوان البث الفرعي للشبكة القياسية class C (e.g. 192.168.1.255)
            final subnetBroadcast =
                InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255');
            _socket!.send(bytes, subnetBroadcast, discoveryPort);
          }
        }
      }
    } catch (e) {
      log('LocalNodeDiscovery: Broadcast send warning: $e');
    }
  }

  void _handleIncomingDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _socket == null) return;

    final datagram = _socket!.receive();
    if (datagram == null) return;

    try {
      final rawString = utf8.decode(datagram.data);
      final json = jsonDecode(rawString);

      if (json is Map<String, dynamic> &&
          json['protocol'] == discoveryProtocol) {
        final action = json['action'] as String?;

        if (action == 'ANNOUNCE_PRESENCE') {
          final senderIp = datagram.address.address;
          final node = LocalNodeInfo.fromJson(json, senderIp);
          _discoveredNodesController.add(node);
        }
      }
    } catch (_) {
      // تجاهل أي حزم غريبة أخرى على الشبكة
    }
  }

  void dispose() {
    _advertisementTimer?.cancel();
    _socket?.close();
    _socket = null;
    _discoveredNodesController.close();
  }
}

/// ============================================================================
/// 🖥️ 4. خادم المقابس المحلي المدمج (Embedded Local WebSocket Server)
/// ============================================================================

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

    // إرسال ترحيب أولي لتأكيد المقبس
    final welcome = P2pMessage.create(
      type: P2pMessageType.handshake,
      payload: {
        'status': 'accepted',
        'server_time': DateTime.now().toIso8601String(),
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
              // الرد بنبضة حية فورية
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

/// ============================================================================
/// 📱 5. عميل المقابس المحلي الفائق السرعة (Local WebSocket Client)
/// ============================================================================

enum LocalClientState { disconnected, connecting, connected }

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