// lib/core/services/camera_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionState {
  granted,
  denied,
  permanentlyDenied,
}

enum CameraCaptureError {
  none,
  permissionDenied,
  noHardwareFound,
  hardwareBusy,
  timeout,
  unknown,
}

class CameraCaptureResult {
  const CameraCaptureResult({
    this.base64Image,
    this.error = CameraCaptureError.none,
    this.errorMessage,
  });

  final String? base64Image;
  final CameraCaptureError error;
  final String? errorMessage;

  bool get isSuccess => error == CameraCaptureError.none && base64Image != null;
}

class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  static const MethodChannel _systemChannel = MethodChannel('com.beaconos/system');

  bool _isCapturing = false;
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// فحص حالة إذن الكاميرا الحالية مع حماية بيئات سطح المكتب
  Future<CameraPermissionState> getPermissionState() async {
    if (!_isMobile) {
      return CameraPermissionState.granted;
    }

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        return CameraPermissionState.granted;
      } else if (status.isPermanentlyDenied) {
        return CameraPermissionState.permanentlyDenied;
      } else {
        return CameraPermissionState.denied;
      }
    } catch (_) {
      return CameraPermissionState.granted;
    }
  }

  /// طلب إذن استخدام الكاميرا من نظام التشغيل
  Future<bool> requestCameraPermission() async {
    if (!_isMobile) return true;

    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  /// فتح شاشة إعدادات التطبيق في النظام في حال الرفض الدائم
  Future<bool> openSettings() async {
    if (!_isMobile) return false;
    return openAppSettings();
  }

  /// التقاط صورة مع فك تعارض الكشاف العتادي والتنظيف الصارم للملفات المؤقتة
  Future<CameraCaptureResult> captureFrame({
    bool enableTorch = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_isCapturing) {
      return const CameraCaptureResult(
        error: CameraCaptureError.hardwareBusy,
        errorMessage: 'Camera is currently busy capturing another frame.',
      );
    }
    _isCapturing = true;

    // 1. التحقق من صلاحية الكاميرا للهواتف
    if (_isMobile) {
      final isGranted = await Permission.camera.isGranted;
      if (!isGranted) {
        final requested = await Permission.camera.request();
        if (!requested.isGranted) {
          log('CameraService: Camera permission denied by user.');
          _isCapturing = false;
          return const CameraCaptureResult(
            error: CameraCaptureError.permissionDenied,
            errorMessage: 'Camera permission denied.',
          );
        }
      }
    }

    // 2. 🛡️ فك تعارض الكشاف العتادي (حل مشكلة CAMERA_IN_USE)
    // إذا كان كشاف النظام مشتغلاً عبر CameraManager، يجب إطفاؤه مسبقاً للسماح لـ CameraController بالفتح
    bool wasSystemTorchOn = false;
    if (_isMobile && Platform.isAndroid) {
      try {
        final isTorchActive = await _systemChannel.invokeMethod<bool>('isFlashlightOn') ?? false;
        if (isTorchActive) {
          wasSystemTorchOn = true;
          await _systemChannel.invokeMethod<bool>('toggleFlashlight', {'enable': false});
          // مهلة قصيرة للنظام لتحرير مورد الكاميرا في الهاردوير
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        log('CameraService: Could not query or release system torch: $e');
      }
    }

    CameraController? controller;
    String? tempFilePath;

    try {
      final List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } catch (e) {
        log('CameraService: availableCameras() failed or unsupported: $e');
        return const CameraCaptureResult(
          error: CameraCaptureError.noHardwareFound,
          errorMessage: 'No cameras detected or platform not supported.',
        );
      }

      if (cameras.isEmpty) {
        log('CameraService: No physical cameras found.');
        return const CameraCaptureResult(
          error: CameraCaptureError.noHardwareFound,
          errorMessage: 'No cameras detected on this device.',
        );
      }

      final targetCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize().timeout(const Duration(seconds: 4));

      // ⚡️ تفعيل الفلاش الداخلي للجلسة إن طُلب أو كان مشتعلاً سابقاً
      final shouldFireTorch = enableTorch || wasSystemTorchOn;
      if (shouldFireTorch && _isMobile) {
        try {
          await controller.setFlashMode(FlashMode.torch);
          await Future<void>.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          log('CameraService: FlashMode.torch not supported on this lens: $e');
        }
      }

      final XFile file = await controller.takePicture().timeout(
        const Duration(seconds: 4),
      );
      tempFilePath = file.path;

      if (shouldFireTorch && _isMobile) {
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
      }

      final bytes = await File(tempFilePath).readAsBytes();
      final base64String = base64Encode(bytes);

      log('CameraService: Frame captured (${bytes.lengthInBytes} bytes).');
      return CameraCaptureResult(base64Image: base64String);
    } on TimeoutException {
      log('CameraService: Capture timed out.');
      return const CameraCaptureResult(
        error: CameraCaptureError.timeout,
        errorMessage: 'Camera hardware timed out.',
      );
    } on CameraException catch (e, st) {
      log('CameraService: CameraException [${e.code}]: ${e.description}', stackTrace: st);
      return CameraCaptureResult(
        error: CameraCaptureError.hardwareBusy,
        errorMessage: e.description ?? e.code,
      );
    } catch (e, st) {
      log('CameraService: General error during capture: $e', stackTrace: st);
      return CameraCaptureResult(
        error: CameraCaptureError.unknown,
        errorMessage: e.toString(),
      );
    } finally {
      // 🧹 1. ضمان حذف ملف الصورة المؤقتة فوراً من الذاكرة
      if (tempFilePath != null) {
        try {
          final fileToDelete = File(tempFilePath);
          if (await fileToDelete.exists()) {
            await fileToDelete.delete();
          }
        } catch (e) {
          log('CameraService: Failed to delete temp file: $e');
        }
      }

      // 🧹 2. تحرير الكاميرا وإغلاق الجلسة
      try {
        await controller?.dispose();
      } catch (_) {}

      // 🧹 3. إعادة تشغيل كشاف النظام إذا كان يعمل قبل عملية الفحص
      if (wasSystemTorchOn && _isMobile && Platform.isAndroid) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await _systemChannel.invokeMethod<bool>('toggleFlashlight', {'enable': true});
        } catch (_) {}
      }

      _isCapturing = false;
    }
  }

  /// دالة توافقية سريعة للاستدعاء المباشر
  Future<String?> captureAsBase64({bool enableTorch = false}) async {
    final result = await captureFrame(enableTorch: enableTorch);
    return result.base64Image;
  }

  void dispose() {}
}