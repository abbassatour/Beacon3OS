// packages/launcher_repository/lib/src/models/remote_action_event.dart
import 'package:cloud_sync_api/cloud_sync_api.dart';

/// أنواع الأوامر الواردة عن بُعد (سواء عبر الواي فاي المحلي أو السحابة أو أليكسا)
enum RemoteActionType {
  locateDevice,
  triggerSos,
  vaultMutation,
  ringAlert,
  navigateFloor, // 👈 نوع الأمر الجديد للتحكم بمصعد الهاتف عن بعد
  unknown,
}

/// كائن يمثل الأمر الوارد لحظياً
class RemoteActionEvent {
  const RemoteActionEvent({
    required this.id,
    required this.actionType,
    this.payload = const {},
  });

  final String id;
  final RemoteActionType actionType;
  final Map<String, dynamic> payload;

  factory RemoteActionEvent.fromMap(Map<String, dynamic> map) {
    final rawType = (map['action_type'] as String? ?? '').toUpperCase();
    RemoteActionType type;
    switch (rawType) {
      case 'LOCATE_DEVICE':
        type = RemoteActionType.locateDevice;
        break;
      case 'TRIGGER_SOS':
        type = RemoteActionType.triggerSos;
        break;
      case 'VAULT_MUTATION':
        type = RemoteActionType.vaultMutation;
        break;
      case 'RING_ALERT':
        type = RemoteActionType.ringAlert;
        break;
      case 'NAVIGATE_FLOOR':
        type = RemoteActionType.navigateFloor;
        break;
      default:
        if (map['payload'] is Map<String, dynamic> &&
            map['payload']['is_ring'] == true) {
          type = RemoteActionType.ringAlert;
        } else {
          type = RemoteActionType.unknown;
        }
    }

    return RemoteActionEvent(
      id: map['id'] as String? ?? '',
      actionType: type,
      payload: map['payload'] is Map<String, dynamic>
          ? map['payload'] as Map<String, dynamic>
          : const {},
    );
  }

  factory RemoteActionEvent.fromP2pMessage(P2pMessage message) {
    RemoteActionType type;
    switch (message.type) {
      case P2pMessageType.locateDevice:
        type = RemoteActionType.locateDevice;
        break;
      case P2pMessageType.triggerSos:
        type = RemoteActionType.triggerSos;
        break;
      case P2pMessageType.vaultMutation:
        type = RemoteActionType.vaultMutation;
        break;
      default:
        final actionStr = (message.payload['action_type'] as String? ?? '').toUpperCase();
        if (actionStr == 'NAVIGATE_FLOOR') {
          type = RemoteActionType.navigateFloor;
        } else if (message.payload['is_ring'] == true) {
          type = RemoteActionType.ringAlert;
        } else {
          type = RemoteActionType.unknown;
        }
    }

    return RemoteActionEvent(
      id: message.id,
      actionType: type,
      payload: message.payload,
    );
  }
}