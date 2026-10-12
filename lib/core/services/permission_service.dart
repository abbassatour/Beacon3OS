// lib/core/services/permission_service.dart
import 'dart:developer';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  static const List<Permission> _requiredPermissions = [
    Permission.microphone,
    Permission.camera,
    Permission.location,
    Permission.contacts,
    Permission.phone,
    Permission.notification,
  ];

  /// طلب كافة الأذونات دفعة واحدة (مع حماية أنظمة سطح المكتب)
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    // 🛡️ على أنظمة سطح المكتب (ويندوز وغيره)، لا نطلب أذونات أندرويد
    if (!Platform.isAndroid && !Platform.isIOS) {
      log('PermissionService: Desktop environment detected. Bypassing mobile permission requests.');
      return {
        for (final perm in _requiredPermissions) perm: PermissionStatus.granted,
      };
    }

    log('PermissionService: Requesting all system permissions...');
    try {
      final statuses = await _requiredPermissions.request();
      statuses.forEach((permission, status) {
        log('PermissionService: $permission -> $status');
      });
      return statuses;
    } catch (e, st) {
      log('PermissionService: Error requesting permissions: $e', stackTrace: st);
      return {};
    }
  }

  /// فحص هل الأذونات الحرجة ممنوحة
  Future<bool> hasAllCriticalPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    for (final perm in [
      Permission.microphone,
      Permission.camera,
      Permission.location,
    ]) {
      final status = await perm.status;
      if (!status.isGranted) return false;
    }
    return true;
  }
}