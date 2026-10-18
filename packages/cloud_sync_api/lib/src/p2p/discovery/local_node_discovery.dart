// packages/cloud_sync_api/lib/src/p2p/discovery/local_node_discovery.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_sync_api/src/p2p/models/local_node_info.dart';

/// محرك الاستكشاف المحلي الصامت عبر UDP (Zero-Config UDP Discovery)
/// تم ضبط طوابع توقيت حزم الاستكشاف لتعمل بالتوقيت العالمي الموحد (UTC).
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

  /// تهيئة مقبس الـ UDP للاستماع والإرسال بأمان على كافة المنصات
  Future<bool> initialize() async {
    if (_socket != null) return true;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
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
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });

    final bytes = utf8.encode(payload);
    await _sendToBroadcastAddresses(bytes);
    log('LocalNodeDiscovery: 🔍 Sent discovery probe on local network (UTC).');
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
      // تجاهل الحزم الغريبة على الشبكة
    }
  }

  void dispose() {
    _advertisementTimer?.cancel();
    _socket?.close();
    _socket = null;
    _discoveredNodesController.close();
  }
}