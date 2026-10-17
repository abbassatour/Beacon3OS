// lib/mobile/perimeter/cubit/perimeter_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/mobile/perimeter/cubit/perimeter_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class PerimeterCubit extends Cubit<PerimeterState> {
  PerimeterCubit({
    required RingRepository ringRepository,
    required AssistantRepository assistantRepository,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _ringRepo = ringRepository,
        _assistant = assistantRepository,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const PerimeterState()) {
    _initStreams();
  }

  final RingRepository _ringRepo;
  final AssistantRepository _assistant;
  final HapticManager _haptics;
  final SoundController _sound;

  StreamSubscription<List<RingDeviceEntity>>? _devicesSub;
  StreamSubscription<List<RingEventEntity>>? _eventsSub;
  StreamSubscription<RingEvent>? _liveEventSub;

  void _initStreams() {
    emit(state.copyWith(status: PerimeterStatus.loading));

    // 1. مراقبة قائمة الكاميرات وتحديثها لحظياً
    _devicesSub = _ringRepo.watchDevices().listen(
      (deviceList) {
        emit(
          state.copyWith(
            status: PerimeterStatus.success,
            devices: deviceList,
            selectedDeviceId: state.selectedDeviceId ??
                (deviceList.isNotEmpty ? deviceList.first.id : null),
          ),
        );
      },
      onError: (Object error) {
        log('PerimeterCubit: Error watching devices: $error');
        emit(
          state.copyWith(
            status: PerimeterStatus.error,
            errorMessage: 'Failed to load Ring devices: $error',
          ),
        );
      },
    );

    // 2. مراقبة سجل الأحداث الأمنية والتنبيهات
    _eventsSub = _ringRepo.watchRecentEvents().listen(
      (eventsList) {
        emit(
          state.copyWith(
            status: PerimeterStatus.success,
            recentEvents: eventsList,
          ),
        );
      },
      onError: (Object error) {
        log('PerimeterCubit: Error watching events: $error');
      },
    );

    // 3. الاستماع المباشر للأحداث الواردة لتشغيل الاهتزاز والنغمات
    _liveEventSub = _ringRepo.liveEventsStream.listen(
      (event) async {
        await _haptics.successNotification();
        if (event.type == RingEventType.ding) {
          await _sound.play(SoundCue.wake);
        } else {
          await _sound.play(SoundCue.navMove);
        }
      },
    );
  }

  /// تغيير الكاميرا المحددة للمعاينة
  void selectDevice(String deviceId) {
    if (state.selectedDeviceId == deviceId) return;
    _haptics.selectionClick();
    _sound.play(SoundCue.navCenter);

    emit(
      state.copyWith(
        selectedDeviceId: deviceId,
        clearInspectionText: true,
      ),
    );

    final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
    if (device != null) {
      _assistant.speak('${device.label} selected. Battery at ${device.batteryLevel} percent.');
    }
  }

  /// فحص مباشر للكاميرا المحددة عبر Gemini 2.0 Flash ونطق المشهد صوتياً لمرة واحدة
  Future<void> inspectCamera({
    String? deviceId,
    String? customQuery,
  }) async {
    final targetId = deviceId ?? state.selectedDeviceId;
    if (targetId == null) return;

    final targetDevice =
        state.devices.where((d) => d.id == targetId).firstOrNull;
    final label = targetDevice?.label ?? 'Security Camera';

    emit(
      state.copyWith(
        status: PerimeterStatus.inspecting,
        clearInspectionText: true,
      ),
    );

    await _sound.play(SoundCue.processing);
    _haptics.startListeningPulse();
    await _assistant.speak('Inspecting live video feed from $label...');

    try {
      final description = await _ringRepo.inspectCameraLive(
        deviceId: targetId,
        customQuery: customQuery,
      );

      _haptics.stopListeningPulse();
      await _sound.play(SoundCue.success);
      await _haptics.successNotification();

      emit(
        state.copyWith(
          status: PerimeterStatus.success,
          liveInspectionText: description,
        ),
      );

      // 🔊 النطق الصوتي الأحادي لمرة واحدة هنا لمنع النطق المزدوج
      if (description != null && description.isNotEmpty) {
        await _assistant.speak(description);
      }
    } catch (e) {
      _haptics.stopListeningPulse();
      await _sound.play(SoundCue.error);
      await _haptics.errorAlert();

      final errorMsg = 'Failed to inspect $label: $e';
      emit(
        state.copyWith(
          status: PerimeterStatus.error,
          errorMessage: errorMsg,
        ),
      );
      await _assistant.speak('Could not inspect camera feed.');
    }
  }

  /// فتح قناة المحادثة الصوتية ثنائية الاتجاه (Two-Way Audio)
  Future<void> startTwoWayAudio(String deviceId) async {
    final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
    final label = device?.label ?? 'Doorbell';

    await _sound.play(SoundCue.wake);
    await _haptics.successNotification();

    emit(
      state.copyWith(
        status: PerimeterStatus.answeringAudio,
        isTwoWayAudioActive: true,
        activeAudioDeviceId: deviceId,
      ),
    );

    await _ringRepo.answerDoorbell(deviceId);
    await _assistant.speak('Two-way audio connected to $label. You can speak now.');
  }

  /// إنهاء قناة المحادثة الصوتية وتحرير مورد العتاد
  Future<void> stopTwoWayAudio() async {
    final activeId = state.activeAudioDeviceId;
    if (activeId != null) {
      await _ringRepo.stopTwoWayAudio(activeId);
    }

    await _sound.play(SoundCue.navCenter);
    _haptics.selectionClick();

    emit(
      state.copyWith(
        status: PerimeterStatus.success,
        isTwoWayAudioActive: false,
        clearAudioDevice: true,
      ),
    );

    await _assistant.speak('Two-way audio disconnected.');
  }

  /// تفعيل أو تعطيل استشعار الحركة وحفظ التفضيل في الخزنة
  Future<void> toggleDeviceMotion(String deviceId, bool isMotionEnabled) async {
    _haptics.selectionClick();
    await _ringRepo.toggleDeviceMotion(id: deviceId, isMotionEnabled: isMotionEnabled);

    final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
    final label = device?.label ?? 'Camera';
    final status = isMotionEnabled ? 'enabled' : 'disabled';
    await _assistant.speak('Motion detection for $label $status.');
  }

  /// تغيير حالة الاتصال للكاميرا (أونلاين / أوفلاين)
  Future<void> toggleDeviceOnlineStatus(String deviceId, bool isOnline) async {
    _haptics.selectionClick();
    await _ringRepo.toggleDeviceOnlineStatus(id: deviceId, isOnline: isOnline);

    final device = state.devices.where((d) => d.id == deviceId).firstOrNull;
    final label = device?.label ?? 'Camera';
    final status = isOnline ? 'online' : 'offline';
    await _assistant.speak('$label set to $status.');
  }

  /// إطلاق سيناريو محاكاة اختباري للمحكمين
  Future<void> triggerScenario(RingScenarioPreset scenario) async {
    await _sound.play(SoundCue.wake);
    await _haptics.successNotification();
    await _ringRepo.triggerSimulatedScenario(scenario);
  }

  /// قراءة تنبيه أو حدث أمني محدد بصوت عالٍ
  Future<void> readEventAloud(RingEventEntity event) async {
    _haptics.selectionClick();
    final timeStr =
        '${event.timestamp.hour % 12 == 0 ? 12 : event.timestamp.hour % 12}:${event.timestamp.minute.toString().padLeft(2, '0')} ${event.timestamp.hour >= 12 ? 'PM' : 'AM'}';
    final desc = event.aiSceneDescription?.isNotEmpty == true
        ? event.aiSceneDescription!
        : 'Activity logged at ${event.deviceLabel}.';

    await _assistant.speak('Alert from ${event.deviceLabel} at $timeStr: $desc');
  }

  @override
  Future<void> close() {
    _devicesSub?.cancel();
    _eventsSub?.cancel();
    _liveEventSub?.cancel();
    return super.close();
  }
}