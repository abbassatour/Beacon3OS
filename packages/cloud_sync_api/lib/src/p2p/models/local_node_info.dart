/// معلومات العقدة المكتشفة في الشبكة المحلية (Local Node Descriptor)
/// تم ضبط طابع توقيت التواجد ليعتمد التوقيت العالمي الموحد (UTC).
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
    DateTime parsedLastSeen = DateTime.now().toUtc();
    if (json['last_seen'] != null) {
      final parsed = DateTime.tryParse(json['last_seen'] as String);
      if (parsed != null) {
        parsedLastSeen = parsed.toUtc();
      }
    } else if (json['timestamp'] != null) {
      final parsed = DateTime.tryParse(json['timestamp'] as String);
      if (parsed != null) {
        parsedLastSeen = parsed.toUtc();
      }
    }

    return LocalNodeInfo(
      nodeId: json['node_id'] as String? ?? 'unknown_node',
      deviceType: json['device_type'] as String? ?? 'display',
      ip: (json['ip'] as String?)?.isNotEmpty == true
          ? json['ip'] as String
          : fallbackIp,
      port: (json['port'] as num?)?.toInt() ?? 8492,
      pairingCode: json['pairing_code'] as String?,
      vaultId: json['vault_id'] as String?,
      lastSeen: parsedLastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'device_type': deviceType,
      'ip': ip,
      'port': port,
      'last_seen': lastSeen.toUtc().toIso8601String(),
      if (pairingCode != null) 'pairing_code': pairingCode,
      if (vaultId != null) 'vault_id': vaultId,
    };
  }

  @override
  String toString() =>
      'LocalNodeInfo($deviceType @ $ip:$port, code: $pairingCode, lastSeenUTC: $lastSeen)';
}