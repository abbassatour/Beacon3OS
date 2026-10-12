// lib/core/services/camera_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
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

  bool _isCapturing = false;
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// فحص حالة إذن الكاميرا الحالية مع حماية سطح المكتب
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

  /// التقاط صورة مع حماية التعارض العتادي مع الفلاش والتحكم بالمهلة الزمنية
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

    // 1. التحقق من صلاحية الكاميرا وطلبها فورياً (للهواتف فقط)
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

    CameraController? controller;
    try {
      final List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } catch (e) {
        log('CameraService: availableCameras() failed or unsupported: $e');
        _isCapturing = false;
        return const CameraCaptureResult(
          error: CameraCaptureError.noHardwareFound,
          errorMessage: 'No cameras detected or platform not supported.',
        );
      }

      if (cameras.isEmpty) {
        log('CameraService: No physical cameras found.');
        _isCapturing = false;
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

      // ⚡️ تشغيل الفلاش بأمان داخل نفس الجلسة (للهواتف فقط)
      if (enableTorch && _isMobile) {
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

      if (enableTorch && _isMobile) {
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
      }

      final bytes = await File(file.path).readAsBytes();
      final base64String = base64Encode(bytes);

      await File(file.path).delete();
      log('CameraService: Frame captured (${bytes.lengthInBytes} bytes).');

      return CameraCaptureResult(base64Image: base64String);
    } on TimeoutException {
      log('CameraService: Capture timed out.');
      return const CameraCaptureResult(
        error: CameraCaptureError.timeout,
        errorMessage: 'Camera hardware timed out.',
      );
    } on CameraException catch (e, st) {
      log('CameraService: CameraException [${e.code}]: ${e.description}',
          stackTrace: st);
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
      try {
        await controller?.dispose();
      } catch (_) {}
      _isCapturing = false;
    }
  }

  /// دالة توافقية سريعة للاستدعاء البسيط
  Future<String?> captureAsBase64({bool enableTorch = false}) async {
    final result = await captureFrame(enableTorch: enableTorch);
    return result.base64Image;
  }

  void dispose() {}
}