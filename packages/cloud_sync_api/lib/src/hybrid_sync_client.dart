// packages/cloud_sync_api/lib/src/hybrid_sync_client.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/src/cloud_sync_client.dart';
import 'package:cloud_sync_api/src/local_p2p_client.dart';

/// حالات نمط النقل والمزامنة الحية في النظام
enum SyncTransportMode {
  discovering, // جاري مسح واكتشاف الشبكة المنزلية
  lanDirect, // اتصال محلي مباشر عبر الواي فاي (< 2ms)
  cloudRelay, // اتصال سحابي عبر Supabase (عالمي / خارج المنزل)
  standalone, // وضع العمل المستقل بدون أجهزة مقترنة
}

/// منسق المزامنة الهجين (Hybrid Sync Orchestrator)
/// يجمع بين السيادة والسرعة الخاطفة محلياً، والتغطية العالمية سحابياً.
/// تم ضبط كافة عمليات المعالجة الزمنية لتعمل بالتوقيت العالمي الموحد (UTC).
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

  // تدفق الإشعار بتغير نمط النقل (لتحديث شارات الواجهة والتوجيه الصوتي للكفيف)
  final StreamController<SyncTransportMode> _transportModeController =
      StreamController<SyncTransportMode>.broadcast();
  Stream<SyncTransportMode> get transportModeStream =>
      _transportModeController.stream;

  // تدفق الأحداث الموحد المصفى من التكرار (Unified Deduplicated Event Stream)
  final StreamController<P2pMessage> _unifiedEventsController =
      StreamController<P2pMessage>.broadcast();
  Stream<P2pMessage> get unifiedEvents => _unifiedEventsController.stream;

  // ذاكرة حماية منع التكرار (Idempotency Cache)
  final Map<String, DateTime> _seenMessageIds = {};
  Timer? _deduplicationCleanupTimer;

  // اشتراكات القنوات والمقابس
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

    // 1. تشغيل مستمع الأوامر السحابية كقناة أمان دائمة
    _listenToCloudRemoteActions();

    // 2. توزيع المهام وفق استراتيجية الطاقة والجاهزية
    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      await _initializeAsHostDisplay();
    } else {
      await _initializeAsMobileClient();
    }
  }

  /// تهيئة الشاشات المنزلية (تلفزيون / سطح مكتب) كخادم محلي دائم
  Future<void> _initializeAsHostDisplay() async {
    _updateMode(SyncTransportMode.discovering);

    final actualPort = await _server.start();
    if (actualPort != null) {
      await _discovery.initialize();

      // إعلان الوجود بانتظام عبر شبكة الواي فاي
      _discovery.startAdvertising(
        nodeId: _nodeId,
        deviceType: _deviceType,
        listeningPort: actualPort,
        pairingCode: _pairingCode,
        vaultId: _linkedVaultId,
      );

      // الاستماع للرسائل الواردة من الهواتف المتصلة محلياً
      _serverMessagesSubscription?.cancel();
      _serverMessagesSubscription = _server.incomingMessages.listen(
        _handleIncomingP2pMessage,
        onError: (Object err) => log('HybridSync: Server message error: $err'),
      );

      _updateMode(SyncTransportMode.lanDirect);
      log('HybridSync: 📺 Host Display ready. Listening on LAN Port $actualPort');
    } else {
      _updateMode(SyncTransportMode.cloudRelay);
      log('HybridSync: Local server unavailable. Defaulting to Cloud Relay.');
    }
  }

  /// تهيئة الهاتف كعميل يكتشف الشاشات المنزلية فوراً ويتصل بها
  Future<void> _initializeAsMobileClient() async {
    _updateMode(SyncTransportMode.discovering);

    await _discovery.initialize();

    // الاستماع للشاشات المكتشفة على نفس شبكة الواي فاي
    _discoverySubscription?.cancel();
    _discoverySubscription = _discovery.discoveredNodes.listen(
      _handleDiscoveredNode,
      onError: (Object err) => log('HybridSync: Discovery stream error: $err'),
    );

    // الاستماع لتغير حالة اتصال العميل بالمقبس المحلي
    _clientStateSubscription?.cancel();
    _clientStateSubscription = _client.stateChanges.listen((state) {
      if (state == LocalClientState.connected) {
        _updateMode(SyncTransportMode.lanDirect);
      } else if (state == LocalClientState.disconnected) {
        _updateMode(
          _cloud.isAuthenticated
              ? SyncTransportMode.cloudRelay
              : SyncTransportMode.standalone,
        );
      }
    });

    // استقبال الرسائل الواردة من التلفزيون/الكمبيوتر
    _clientMessagesSubscription?.cancel();
    _clientMessagesSubscription = _client.incomingMessages.listen(
      _handleIncomingP2pMessage,
      onError: (Object err) => log('HybridSync: Client message error: $err'),
    );

    // إرسال نداء استكشاف أولي فوري في الشبكة
    await _discovery.probeForNodes();
  }

  /// التعامل مع العقدة المكتشفة بالواي فاي والاتصال بها بحذر ودقة
  Future<void> _handleDiscoveredNode(LocalNodeInfo node) async {
    if (_client.isConnected) return;

    // فحص هل هذا الجهاز يطابق كود الاقتران النشط أو الخزنة المشتركة
    final matchesCode =
        _pairingCode != null && node.pairingCode != null && node.pairingCode == _pairingCode;
    final matchesVault =
        _linkedVaultId != null && node.vaultId != null && node.vaultId == _linkedVaultId;
    final isAuthorizedPeer = matchesCode || matchesVault;

    if (isAuthorizedPeer) {
      log('HybridSync: 🎯 Target authorized peer found on LAN (${node.ip}:${node.port}). Connecting...');
      final connected = await _client.connectToNode(node);
      if (connected) {
        _updateMode(SyncTransportMode.lanDirect);
      }
    }
  }

  // ===========================================================================
  // 🔄 2. إدارة وتحديث حالة الاقتران والفك (Lifecycle & Session Reset)
  // ===========================================================================

  /// تحديث كود الاقتران اللحظي وإعادة إعلانه عبر الـ UDP لمنع بقاء الأكواد القديمة
  void updatePairingCode(String? newCode) {
    _pairingCode = newCode;
    log('HybridSync: 🔄 Pairing code updated to: $newCode');

    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      if (_server.isRunning) {
        _discovery.startAdvertising(
          nodeId: _nodeId,
          deviceType: _deviceType,
          listeningPort: _server.port,
          pairingCode: _pairingCode,
          vaultId: _linkedVaultId,
        );
      }
    }
  }

  /// تحديث معرف الخزنة المقترنة بعد إتمام الربط بنجاح
  void updateLinkedVaultId(String? vaultId) {
    _linkedVaultId = vaultId;
    _pairingCode = null; // إبطال الكود بمجرد اعتماد الخزنة
    log('HybridSync: 🗝️ Linked Vault ID updated to: $vaultId');

    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      if (_server.isRunning) {
        _discovery.startAdvertising(
          nodeId: _nodeId,
          deviceType: _deviceType,
          listeningPort: _server.port,
          pairingCode: null,
          vaultId: _linkedVaultId,
        );
      }
    }
  }

  /// 🧹 التطهير الكامل للشبكة عند إلغاء الاقتران للسماح بربط جهاز آخر بسلاسة
  Future<void> unpairAndReset() async {
    log('HybridSync: 🧹 Cleaning up active network pairing and resetting session...');
    _linkedVaultId = null;
    _pairingCode = null;
    _seenMessageIds.clear();

    await _client.disconnect();

    if (_deviceType == 'fire_tv' || _deviceType == 'desktop') {
      if (_server.isRunning) {
        // إعادة البث بحالة فارغة بدون كود أو خزنة سابقة
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

    // 1. المحاولة عبر المسار المحلي (< 2ms)
    final sentLocally = _sendViaLocalTransport(message);
    if (sentLocally) {
      log('HybridSync: ⚡ Locate Phone command delivered directly via LAN.');
      return true;
    }

    // 2. المسار البديل عبر السحابة
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
    required String action, // 'INSERT', 'UPDATE', 'DELETE'
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
  // 🛡️ 4. معالجة الرسائل الواردة ومنع التكرار (Deduplication)
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
  // 🛑 5. تحرير الموارد وإغلاق القنوات
  // ===========================================================================

  void dispose() {
    _deduplicationCleanupTimer?.cancel();
    _discoverySubscription?.cancel();
    _clientStateSubscription?.cancel();
    _clientMessagesSubscription?.cancel();
    _serverMessagesSubscription?.cancel();
    _cloudRemoteActionsSub?.cancel();

    _discovery.dispose();
    _server.dispose();
    _client.dispose();

    _transportModeController.close();
    _unifiedEventsController.close();
  }
}