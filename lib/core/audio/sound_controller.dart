// lib/core/audio/sound_controller.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/spatial_direction.dart';
import 'package:flutter/widgets.dart';

/// وحدة التحكم المركزية بالهندسة الصوتية المكانية لنظام BeaconOS.
///
/// تم ضبطها بمعايير التردد الحسي النفسي (Psychoacoustics) لتوفير
/// استجابة مكانية دقيقة دون إجهاد قنوات المنصة (MethodChannel).
class SoundController {
  SoundController._() {
    _primaryPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _navPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _radarPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  }

  static final SoundController instance = SoundController._();

  late final AudioPlayer _primaryPlayer;
  late final AudioPlayer _navPlayer;
  late final AudioPlayer _radarPlayer;

  bool isEnabled = true;

  bool _isRadarActive = false;
  bool _isInCoreZone = false;

  double _lastBalance = 0.0;
  double _lastPlaybackRate = 1.0;
  double _lastVolume = 0.0;
  DateTime _lastThrottledUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  // 🎛️ عتبات التكميم الصوتي (Perceptual Deadband Filter)
  static const double _balanceEpsilon = 0.055; // 5.5% عتبة تغير الستيريو
  static const double _rateEpsilon = 0.050; // 5.0% عتبة تغير النغمة/التردد
  static const double _volumeEpsilon = 0.040; // 4.0% عتبة تغير العلو

  // ⏱️ زمن التحديث الأمثل (~24Hz): نعومة تامة للأذن مع استقرار إطارات الشاشة
  static const Duration _throttleInterval = Duration(milliseconds: 42);

  Future<void> play(
    SoundCue cue, {
    int floorLevel = 0,
    bool isSettingsFloor = false,
    double? volumeOverride,
  }) async {
    if (!isEnabled && cue != SoundCue.sosAlarm) return;

    final isNav = cue.allowFloorPitchShift ||
        cue.name.startsWith('nav') ||
        cue.name.startsWith('elevator');
    final player = isNav ? _navPlayer : _primaryPlayer;

    try {
      await player.stop();
      if (cue.isLooping) {
        await player.setReleaseMode(ReleaseMode.loop);
      }
      await player.setVolume(volumeOverride ?? cue.volume);

      final effectiveFloor = isSettingsFloor ? 1 : floorLevel;
      final playbackRate = cue.allowFloorPitchShift
          ? (1.0 + (effectiveFloor * 0.15)).clamp(0.5, 2.0)
          : 1.0;

      await player.setPlaybackRate(playbackRate);
      await player.setBalance(0.0);
      await player.play(AssetSource(cue.path));
    } catch (e) {
      log('SoundController: Play skipped for [${cue.name}]: $e');
    }
  }

  Future<void> playCompassMove({
    required CompassDirection direction,
    int floorLevel = 0,
  }) async {
    if (!isEnabled) return;

    try {
      await _navPlayer.stop();

      if (direction == CompassDirection.center) {
        await _navPlayer.setVolume(SoundCue.navReturn.volume);
        await _navPlayer.setPlaybackRate(1.0);
        await _navPlayer.setBalance(0.0);
        await _navPlayer.play(AssetSource(SoundCue.navReturn.path));
        return;
      }

      double baseRate = 1.0;
      double stereoBalance = 0.0;

      switch (direction) {
        case CompassDirection.north:
          baseRate = 1.28;
          stereoBalance = 0.0;
          break;
        case CompassDirection.south:
          baseRate = 0.82;
          stereoBalance = 0.0;
          break;
        case CompassDirection.east:
          baseRate = 1.15;
          stereoBalance = 0.60;
          break;
        case CompassDirection.west:
          baseRate = 0.95;
          stereoBalance = -0.60;
          break;
        case CompassDirection.center:
          break;
      }

      final effectiveRate = (baseRate + (floorLevel * 0.12)).clamp(0.6, 2.0);

      await _navPlayer.setVolume(SoundCue.navMove.volume);
      await _navPlayer.setPlaybackRate(effectiveRate);
      await _navPlayer.setBalance(stereoBalance);
      await _navPlayer.play(AssetSource(SoundCue.navMove.path));
    } catch (e) {
      log('SoundController: Compass sound skipped: $e');
    }
  }

  Future<void> startSpatialRadar({int floorLevel = 0}) async {
    if (!isEnabled || _isRadarActive) return;

    _isRadarActive = true;
    _isInCoreZone = true;
    _lastBalance = 0.0;
    _lastPlaybackRate = 1.0 + (floorLevel * 0.12);
    _lastVolume = 0.15;
    _lastThrottledUpdate = DateTime.now();

    try {
      await _radarPlayer.stop();
      await _radarPlayer.setVolume(_lastVolume);
      await _radarPlayer.setPlaybackRate(_lastPlaybackRate);
      await _radarPlayer.setBalance(_lastBalance);
      await _radarPlayer.play(AssetSource(SoundCue.radarDrone.path));
    } catch (e) {
      log('SoundController: Radar start error: $e');
    }
  }

  Future<void> updateSpatialRadar({
    required double normalizedX,
    required double normalizedY,
    int floorLevel = 0,
  }) async {
    if (!isEnabled || !_isRadarActive) return;

    final now = DateTime.now();
    // فحص الخنق الزمني لحماية Platform Thread
    if (now.difference(_lastThrottledUpdate) < _throttleInterval) {
      return;
    }
    _lastThrottledUpdate = now;

    final nx = normalizedX.clamp(-1.0, 1.0);
    final ny = normalizedY.clamp(-1.0, 1.0);
    final r = math.sqrt(nx * nx + ny * ny).clamp(0.0, 1.414);

    final targetBalance = nx;
    final floorPitchOffset = floorLevel * 0.12;
    final targetRate =
        (1.0 + (ny * 0.32) + floorPitchOffset).clamp(0.65, 1.85);
    final targetVolume = (0.12 + (r * 0.28)).clamp(0.08, 0.45);

    try {
      // إرسال الستيريو فقط إذا تجاوز عتبة التمييز الإدراكي
      if ((targetBalance - _lastBalance).abs() > _balanceEpsilon) {
        _lastBalance = targetBalance;
        unawaited(_radarPlayer.setBalance(targetBalance));
      }

      // إرسال التردد فقط إذا تجاوز عتبة التمييز
      if ((targetRate - _lastPlaybackRate).abs() > _rateEpsilon) {
        _lastPlaybackRate = targetRate;
        unawaited(_radarPlayer.setPlaybackRate(targetRate));
      }

      // إرسال علو الصوت فقط إذا تجاوز عتبة التمييز
      if ((targetVolume - _lastVolume).abs() > _volumeEpsilon) {
        _lastVolume = targetVolume;
        unawaited(_radarPlayer.setVolume(targetVolume));
      }
    } catch (_) {}

    // الانتقال السلس لمنطقة المركز ونغمة القلب
    if (r < 0.15 && !_isInCoreZone) {
      _isInCoreZone = true;
      unawaited(playCoreChime());
    } else if (r > 0.25 && _isInCoreZone) {
      _isInCoreZone = false;
    }
  }

  Future<void> stopSpatialRadar() async {
    if (!_isRadarActive) return;
    _isRadarActive = false;
    _isInCoreZone = false;

    try {
      await _radarPlayer.stop();
    } catch (e) {
      log('SoundController: Radar stop error: $e');
    }
  }

  Future<void> playCoreChime() async {
    await play(SoundCue.coreChime, volumeOverride: 0.24);
  }

  Future<void> playBoundaryBump() async {
    await play(SoundCue.boundaryThud, volumeOverride: 0.38);
  }

  Future<void> stopAll() async {
    try {
      _isRadarActive = false;
      await _primaryPlayer.stop();
      await _navPlayer.stop();
      await _radarPlayer.stop();
    } catch (e) {
      log('SoundController: Error stopping audio: $e');
    }
  }

  void dispose() {
    _primaryPlayer.dispose();
    _navPlayer.dispose();
    _radarPlayer.dispose();
  }
}

extension SoundContextX on BuildContext {
  SoundController get sounds => SoundController.instance;
}