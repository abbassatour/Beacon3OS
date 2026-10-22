// packages/cloud_sync_api/lib/src/hybrid_sync_client.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_sync_api/src/cloud_sync_client.dart';
import 'package:cloud_sync_api/src/local_p2p_client.dart';

/// حالات نمط النقل والمزامنة الحية في النظام
enum SyncTransportMode {
  discovering, // جاري مسح واكتشاف الشبكة المنزلية
  lanDirect,   // اتصال محلي مباشر وآمن عبر الواي فاي (< 2ms)
  cloudRelay,  // اتصال سحابي عبر Supabase (عالمي / خارج المنزل)
  standalone,  // وضع العمل المستقل بدون أجهزة مقترنة
}

/// منسق المزامنة الهجين المؤمن (Secure Hybrid Sync Orchestrator)
class HybridSyncClient {
  HybridSyncClient({
    CloudSyncClient? cloudSyncClient,
    LocalNodeDiscovery? discovery,
    LocalNodeServer? server,
    LocalNodeClient? client,
  })  : _cloud = cloudSyncClient ?? CloudSyncClient(),
        _discovery = discovery ?? LocalNodeDiscovery(),
        _server = server ?? LocalNodeServer(),
        _client = client ?? LocalNodeClient();

  final CloudSyncClient _cloud;
  final LocalNodeDiscovery _discovery;
  final LocalNodeServer _server;
  final LocalNodeClient _client;

  String _deviceType = 'phone';
  String _nodeId = 'node_primary';
  String? _pairingCode;
  String? _linkedVaultId;

  SyncTransportMode _currentMode = SyncTransportMode.discovering;
  SyncTransportMode get currentMode => _currentMode;
  bool get isLanDirect => _currentMode == SyncTransportMode.lanDirect;

  // 📡 قائمة وتدفق الأجهزة النشطة في الشبكة المحلية
  final Map<String, LocalNodeInfo> _peersMap = {};
  Timer? _peerEvictionTimer;
  Timer? _emulatorProbeTimer;

  final StreamController<List<LocalNodeInfo>> _activePeersController =
      StreamController<List<LocalNodeInfo>>.broadcast();

  Stream<List<LocalNodeInfo>> get activePeersStream =>
      _activePeersController.stream;
  List<LocalNodeInfo> get activePeers => _peersMap.values.toList();
  List<LocalNodeInfo> get activeMeshNodes => activePeers;

  final StreamController<SyncTransportMode> _transportModeController =
      StreamController<SyncTransportMode>.broadcast();
  Stream<SyncTransportMode> get transportModeStream =>
      _transportModeController.stream;

  final StreamController<P2pMessage> _unifiedEventsController =
      StreamController<P2pMessage>.broadcast();
  Stream<P2pMessage> get unifiedEvents => _unifiedEventsController.stream;

  final Map<String, DateTime> _seenMessageIds = {};
  Timer? _deduplicationCleanupTimer;

  StreamSubscription<LocalNodeInfo>? _discoverySubscription;
  StreamSubscription<LocalClientState>? _clientStateSubscription;
  StreamSubscription<P2pMessage>? _clientMessagesSubscription;
  StreamSubscription<P2pMessage>? _serverMessagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _cloudRemoteActionsSub;

  // ===========================================================================
  // 🚀 1. التهيئة والتشغيل الذاتي حسب نوع الجهاز
  // ===========================================================================

  Future<void> initialize({
    required String deviceType, // 'phone', 'fire_tv', 'desktop'
    required String nodeId,
    String? pairingCode,
    String? linkedVaultId,
  }) async {
    _deviceType = deviceType;
    _nodeId = nodeId;
    _pairingCode = pairingCode;
    _linkedVaultId = linkedVaultId;

    _startDeduplicationCleaner();
    _startPeerEvictionTimer();

    // 1. تشغيل مستمع الأوامر السحابية كقناة أمان دائمة
    _listenToCloudRemoteActions();

    // 2. توزيع المهام وفق استراتيجية الجهاز
    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      await _initializeAsHostDisplay();
    } else {
      await _initializeAsMobileClient();
    }
  }

  Future<void> _initializeAsHostDisplay() async {
    _updateMode(SyncTransportMode.discovering);

    _server.updateSecurityCredentials(
      linkedVaultId: _linkedVaultId,
      pairingCode: _pairingCode,
    );

    final actualPort = await _server.start();
    if (actualPort != null) {
      await _discovery.initialize();

      _discovery.startAdvertising(
        nodeId: _nodeId,
        deviceType: _deviceType,
        listeningPort: actualPort,
        pairingCode: _pairingCode,
        vaultId: _linkedVaultId,
      );

      _serverMessagesSubscription?.cancel();
      _serverMessagesSubscription = _server.incomingMessages.listen(
        _handleIncomingP2pMessage,
        onError: (Object err) => log('HybridSync: Server message error: $err'),
      );

      _updateMode(SyncTransportMode.lanDirect);
      log('HybridSync: 📺 Secure Host Display ready on LAN Port $actualPort');
    } else {
      _updateMode(SyncTransportMode.cloudRelay);
      log('HybridSync: Local server unavailable. Defaulting to Cloud Relay.');
    }
  }

  Future<void> _initializeAsMobileClient() async {
    _updateMode(SyncTransportMode.discovering);

    _client.configureCredentials(
      vaultId: _linkedVaultId,
      pairingCode: _pairingCode,
      clientId: _nodeId,
    );

    await _discovery.initialize();

    _discoverySubscription?.cancel();
    _discoverySubscription = _discovery.discoveredNodes.listen(
      _handleDiscoveredNode,
      onError: (Object err) => log('HybridSync: Discovery stream error: $err'),
    );

    _clientStateSubscription?.cancel();
    _clientStateSubscription = _client.stateChanges.listen((clientState) {
      if (clientState == LocalClientState.connected) {
        _updateMode(SyncTransportMode.lanDirect);
      } else if (clientState == LocalClientState.authFailed) {
        log('HybridSync: 🚫 Peer rejected authentication credentials.');
        _updateMode(
          _cloud.isAuthenticated
              ? SyncTransportMode.cloudRelay
              : SyncTransportMode.standalone,
        );
      } else if (clientState == LocalClientState.disconnected) {
        _updateMode(
          _cloud.isAuthenticated
              ? SyncTransportMode.cloudRelay
              : SyncTransportMode.standalone,
        );
      }
    });

    _clientMessagesSubscription?.cancel();
    _clientMessagesSubscription = _client.incomingMessages.listen(
      _handleIncomingP2pMessage,
      onError: (Object err) => log('HybridSync: Client message error: $err'),
    );

    await _discovery.probeForNodes();

    // 🌟 فحص فوري ومستمر لمضيف المحاكي (Windows Host)
    if (Platform.isAndroid) {
      unawaited(_probeEmulatorHost());
      _emulatorProbeTimer?.cancel();
      _emulatorProbeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_client.isConnected && Platform.isAndroid) {
          _probeEmulatorHost();
        }
      });
    }
  }

  /// 🎯 جسر الاتصال الصريح لمحاكي الأندرويد مع الويندوز (10.0.2.2 و 127.0.0.1)
  Future<void> _probeEmulatorHost() async {
    if (!Platform.isAndroid || _client.isConnected) return;

    final hostCandidates = ['10.0.2.2', '127.0.0.1'];
    for (final hostIp in hostCandidates) {
      if (_client.isConnected) break;

      final candidateNode = LocalNodeInfo(
        nodeId: 'host_desktop_$hostIp',
        deviceType: 'desktop',
        ip: hostIp,
        port: 8492,
        pairingCode: _pairingCode,
        vaultId: _linkedVaultId,
        lastSeen: DateTime.now().toUtc(),
      );

      try {
        final connected = await _client.connectToNode(
          candidateNode,
          vaultId: _linkedVaultId,
          pairingCode: _pairingCode,
          clientId: _nodeId,
        );
        if (connected) {
          _peersMap[candidateNode.nodeId] = candidateNode;
          _activePeersController.add(activeMeshNodes);
          _updateMode(SyncTransportMode.lanDirect);
          log('HybridSync: ⚡ Connected directly to Windows host emulator gateway ($hostIp:8492)!');
          break;
        }
      } catch (_) {}
    }
  }

  Future<void> _handleDiscoveredNode(LocalNodeInfo node) async {
    _peersMap[node.nodeId] = node;
    _activePeersController.add(activeMeshNodes);

    if (_client.isConnected) return;

    final matchesCode =
        _pairingCode != null && node.pairingCode != null && node.pairingCode == _pairingCode;
    final matchesVault =
        _linkedVaultId != null && node.vaultId != null && node.vaultId == _linkedVaultId;
    final isAuthorizedPeer = matchesCode || matchesVault;

    if (isAuthorizedPeer) {
      log('HybridSync: 🎯 Target authorized peer found on LAN (${node.ip}:${node.port}). Connecting securely...');
      final connected = await _client.connectToNode(
        node,
        vaultId: _linkedVaultId,
        pairingCode: _pairingCode,
        clientId: _nodeId,
      );
      if (connected) {
        _updateMode(SyncTransportMode.lanDirect);
      }
    }
  }

  void _startPeerEvictionTimer() {
    _peerEvictionTimer?.cancel();
    _peerEvictionTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final now = DateTime.now().toUtc();
      var changed = false;

      _peersMap.removeWhere((id, node) {
        // حماية عقدة المحاكي من الحذف المؤقت
        if (id.startsWith('host_desktop_')) return false;

        final isStale = now.difference(node.lastSeen).inSeconds > 10;
        if (isStale) {
          changed = true;
          log('HybridSync: 🍂 Evicted stale mesh peer: $id (${node.ip})');
        }
        return isStale;
      });

      if (changed) {
        _activePeersController.add(activeMeshNodes);
      }
    });
  }

  // ===========================================================================
  // 🔄 2. إدارة وتحديث حالة الاقتران والفك (Session Management)
  // ===========================================================================

  void updatePairingCode(String? newCode) {
    _pairingCode = newCode;
    log('HybridSync: 🔄 Pairing code updated to: $newCode');

    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      _server.updateSecurityCredentials(
        linkedVaultId: _linkedVaultId,
        pairingCode: _pairingCode,
      );
      if (_server.isRunning) {
        _discovery.startAdvertising(
          nodeId: _nodeId,
          deviceType: _deviceType,
          listeningPort: _server.port,
          pairingCode: _pairingCode,
          vaultId: _linkedVaultId,
        );
      }
    } else {
      _client.configureCredentials(
        vaultId: _linkedVaultId,
        pairingCode: _pairingCode,
        clientId: _nodeId,
      );
      if (Platform.isAndroid && newCode != null) {
        unawaited(_probeEmulatorHost());
      }
    }
  }

  void updateLinkedVaultId(String? vaultId) {
    _linkedVaultId = vaultId;
    _pairingCode = null;
    log('HybridSync: 🗝️ Linked Vault ID updated to: $vaultId');

    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      _server.updateSecurityCredentials(
        linkedVaultId: _linkedVaultId,
        pairingCode: null,
      );
      if (_server.isRunning) {
        _discovery.startAdvertising(
          nodeId: _nodeId,
          deviceType: _deviceType,
          listeningPort: _server.port,
          pairingCode: null,
          vaultId: _linkedVaultId,
        );
      }
    } else {
      _client.configureCredentials(
        vaultId: _linkedVaultId,
        pairingCode: null,
        clientId: _nodeId,
      );
      if (Platform.isAndroid && vaultId != null) {
        unawaited(_probeEmulatorHost());
      }
    }
  }

  Future<void> unpairAndReset() async {
    log('HybridSync: 🧹 Cleaning up active network pairing and resetting session...');
    _linkedVaultId = null;
    _pairingCode = null;
    _seenMessageIds.clear();
    _peersMap.clear();
    _activePeersController.add([]);

    await _client.disconnect();

    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      _server.updateSecurityCredentials(linkedVaultId: null, pairingCode: null);
      if (_server.isRunning) {
        _discovery.startAdvertising(
          nodeId: _nodeId,
          deviceType: _deviceType,
          listeningPort: _server.port,
          pairingCode: null,
          vaultId: null,
        );
      }
      _updateMode(SyncTransportMode.discovering);
    } else {
      _client.configureCredentials(vaultId: null, pairingCode: null);
      _updateMode(
        _cloud.isAuthenticated
            ? SyncTransportMode.cloudRelay
            : SyncTransportMode.standalone,
      );
    }
  }

  // ===========================================================================
  // ⚡ 3. إرسال الأوامر بالمسار المحلي أولاً (Local-First Dispatch)
  // ===========================================================================

  Future<bool> dispatchLocatePhone({
    required String reason,
    String? targetUserId,
  }) async {
    final message = P2pMessage.create(
      type: P2pMessageType.locateDevice,
      payload: {
        'reason': reason,
        'siren_volume': 1.0,
        'strobe_flashlight': true,
      },
      senderId: _nodeId,
      senderType: _deviceType,
    );

    final sentLocally = _sendViaLocalTransport(message);
    if (sentLocally) {
      log('HybridSync: ⚡ Locate Phone command delivered directly via LAN.');
      return true;
    }

    log('HybridSync: LAN unreachable. Routing Locate Phone via Cloud Relay...');
    try {
      await _cloud.acknowledgeRemoteAction(
        'req_${DateTime.now().toUtc().millisecondsSinceEpoch}',
        status: 'pending',
      );
      return true;
    } catch (e) {
      log('HybridSync: Cloud dispatch error: $e');
      return false;
    }
  }

  Future<void> dispatchEmergencySos({
    required double latitude,
    required double longitude,
    int batteryLevel = 100,
  }) async {
    final message = P2pMessage.create(
      type: P2pMessageType.triggerSos,
      payload: {
        'latitude': latitude,
        'longitude': longitude,
        'battery_level': batteryLevel,
        'google_maps_url': 'https://maps.google.com/?q=$latitude,$longitude',
      },
      senderId: _nodeId,
      senderType: _deviceType,
    );

    _sendViaLocalTransport(message);

    _cloud.broadcastEmergencySos(
      id: message.id,
      latitude: latitude,
      longitude: longitude,
      batteryLevel: batteryLevel,
    ).catchError((Object err) {
      log('HybridSync: Cloud SOS backup warning: $err');
      return false;
    });
  }

  void broadcastVaultMutation({
    required String table,
    required String action,
    required Map<String, dynamic> data,
  }) {
    final message = P2pMessage.create(
      type: P2pMessageType.vaultMutation,
      payload: {
        'table': table,
        'action': action,
        'data': data,
      },
      senderId: _nodeId,
      senderType: _deviceType,
    );

    _sendViaLocalTransport(message);
  }

  // ===========================================================================
  // 🔄 4. بروتوكول المزامنة التفاضلية واللقطات (Delta & Snapshot Sync)
  // ===========================================================================

  void requestVaultDelta({DateTime? since}) {
    final message = P2pMessage.create(
      type: P2pMessageType.vaultDeltaRequest,
      payload: {
        'since_utc': since?.toUtc().toIso8601String(),
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      },
      senderId: _nodeId,
      senderType: _deviceType,
    );

    _sendViaLocalTransport(message);
    log('HybridSync: 📤 Dispatched vault delta request via LAN (Since: ${since?.toIso8601String() ?? "initial"}).');
  }

  void sendVaultDelta(Map<String, dynamic> deltaPayload) {
    final message = P2pMessage.create(
      type: P2pMessageType.vaultDeltaResponse,
      payload: deltaPayload,
      senderId: _nodeId,
      senderType: _deviceType,
    );

    _sendViaLocalTransport(message);
    log('HybridSync: 📤 Dispatched vault delta response via LAN.');
  }

  void requestVaultSync() {
    final message = P2pMessage.create(
      type: P2pMessageType.vaultSyncRequest,
      payload: {
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      },
      senderId: _nodeId,
      senderType: _deviceType,
    );

    _sendViaLocalTransport(message);
    log('HybridSync: 📤 Dispatched full vault snapshot request via LAN.');
  }

  void sendVaultSnapshot(Map<String, dynamic> snapshot) {
    final message = P2pMessage.create(
      type: P2pMessageType.vaultSyncResponse,
      payload: snapshot,
      senderId: _nodeId,
      senderType: _deviceType,
    );

    _sendViaLocalTransport(message);
    log('HybridSync: 📤 Dispatched full vault snapshot response via LAN.');
  }

  bool _sendViaLocalTransport(P2pMessage message) {
    if (_deviceType == 'phone') {
      return _client.send(message);
    } else {
      if (_server.clientCount > 0) {
        _server.broadcast(message);
        return true;
      }
    }
    return false;
  }

  // ===========================================================================
  // 🛡️ 5. معالجة الرسائل الواردة ومنع التكرار (Deduplication)
  // ===========================================================================

  void _handleIncomingP2pMessage(P2pMessage message) {
    if (_isDuplicate(message.id)) return;

    log('HybridSync: 📥 Inbound LAN Message -> [${message.type.name}] (ID: ${message.id})');
    _unifiedEventsController.add(message);
  }

  void _listenToCloudRemoteActions() {
    _cloudRemoteActionsSub?.cancel();
    final stream = _cloud.streamRemoteActions();
    if (stream != null) {
      _cloudRemoteActionsSub = stream.listen((actionsList) {
        for (final raw in actionsList) {
          final actionId = raw['id'] as String? ?? '';
          if (_isDuplicate(actionId)) continue;

          final actionType = raw['action_type'] as String? ?? '';
          final payload = raw['payload'] is Map<String, dynamic>
              ? raw['payload'] as Map<String, dynamic>
              : <String, dynamic>{};

          P2pMessageType mappedType = P2pMessageType.unknown;
          if (actionType == 'LOCATE_DEVICE') {
            mappedType = P2pMessageType.locateDevice;
          } else if (actionType == 'TRIGGER_SOS') {
            mappedType = P2pMessageType.triggerSos;
          }

          if (mappedType != P2pMessageType.unknown) {
            final syntheticMessage = P2pMessage(
              id: actionId,
              type: mappedType,
              payload: payload,
              timestamp: DateTime.now().toUtc(),
              senderType: 'cloud',
            );

            log('HybridSync: ☁️ Inbound Cloud Action -> [$actionType] (ID: $actionId)');
            _unifiedEventsController.add(syntheticMessage);
          }
        }
      });
    }
  }

  bool _isDuplicate(String messageId) {
    if (messageId.isEmpty) return false;
    final now = DateTime.now().toUtc();

    if (_seenMessageIds.containsKey(messageId)) {
      log('HybridSync: 🛡️ Duplicate suppressed for ID: $messageId');
      return true;
    }

    _seenMessageIds[messageId] = now.add(const Duration(minutes: 2));
    return false;
  }

  void _startDeduplicationCleaner() {
    _deduplicationCleanupTimer?.cancel();
    _deduplicationCleanupTimer =
        Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now().toUtc();
      _seenMessageIds.removeWhere((_, expiry) => now.isAfter(expiry));
    });
  }

  void _updateMode(SyncTransportMode nextMode) {
    if (_currentMode != nextMode) {
      _currentMode = nextMode;
      _transportModeController.add(_currentMode);
      log('HybridSync: 🧭 Transport mode changed -> ${_currentMode.name.toUpperCase()}');
    }
  }

  // ===========================================================================
  // 🛑 6. تحرير الموارد وإغلاق القنوات
  // ===========================================================================

  void dispose() {
    _deduplicationCleanupTimer?.cancel();
    _peerEvictionTimer?.cancel();
    _emulatorProbeTimer?.cancel();
    _discoverySubscription?.cancel();
    _clientStateSubscription?.cancel();
    _clientMessagesSubscription?.cancel();
    _serverMessagesSubscription?.cancel();
    _cloudRemoteActionsSub?.cancel();

    _discovery.dispose();
    _server.dispose();
    _client.dispose();

    _activePeersController.close();
    _transportModeController.close();
    _unifiedEventsController.close();
  }
}