// lib/core/audio/sound_controller.dart
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:flutter/widgets.dart';

class SoundController {
  SoundController._() {
    _primaryPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _navPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  }

  static final SoundController instance = SoundController._();

  late final AudioPlayer _primaryPlayer;
  late final AudioPlayer _navPlayer;

  bool isEnabled = true;

  /// تشغيل أي نغمة عامة
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
      await player.setReleaseMode(
        cue.isLooping ? ReleaseMode.loop : ReleaseMode.stop,
      );
      await player.setVolume(volumeOverride ?? cue.volume);

      final effectiveFloor = isSettingsFloor ? 1 : floorLevel;
      final playbackRate = cue.allowFloorPitchShift
          ? (1.0 + (effectiveFloor * 0.15)).clamp(0.5, 2.0)
          : 1.0;

      await player.setPlaybackRate(playbackRate);
      await player.setBalance(0.0); // توسيط الاستيريو الافتراضي
      await player.play(AssetSource(cue.path));
    } catch (e) {
      log('SoundController: Failed to play [${cue.name}]: $e');
    }
  }

  /// 🌟 المحرك النغمي للملاحة الفضائية (Harmonic Spatial Compass Engine)
  Future<void> playCompassMove({
    required CompassDirection direction,
    int floorLevel = 0,
  }) async {
    if (!isEnabled) return;

    try {
      await _navPlayer.stop();
      await _navPlayer.setReleaseMode(ReleaseMode.stop);

      // في حال العودة للمركز
      if (direction == CompassDirection.center) {
        await _navPlayer.setVolume(SoundCue.navReturn.volume);
        await _navPlayer.setPlaybackRate(1.0);
        await _navPlayer.setBalance(0.0);
        await _navPlayer.play(AssetSource(SoundCue.navReturn.path));
        return;
      }

      // في حال الانطلاق للغرف: نحسب الطبقة الصوتية والستيريو
      double baseRate = 1.0;
      double stereoBalance = 0.0;

      switch (direction) {
        case CompassDirection.north:
          baseRate = 1.28; // نبرة عالية وواضحة (منبهات وتركيز)
          stereoBalance = 0.0;
          break;
        case CompassDirection.south:
          baseRate = 0.82; // نبرة عميقة دافئة ومستقرة (طوارئ وتواصل)
          stereoBalance = 0.0;
          break;
        case CompassDirection.east:
          baseRate = 1.15; // نبرة متوسطة مشرقة
          stereoBalance = 0.55; // يميل للأذن اليمنى قليلاً 🎧
          break;
        case CompassDirection.west:
          baseRate = 0.96; // نبرة متزنة وهادئة
          stereoBalance = -0.55; // يميل للأذن اليسرى قليلاً 🎧
          break;
        case CompassDirection.center:
          break;
      }

      // رفع طفيف للطبقة عند الوجود في الطابق الثاني
      final effectiveRate = (baseRate + (floorLevel * 0.12)).clamp(0.6, 2.0);

      await _navPlayer.setVolume(SoundCue.navMove.volume);
      await _navPlayer.setPlaybackRate(effectiveRate);
      await _navPlayer.setBalance(stereoBalance);
      await _navPlayer.play(AssetSource(SoundCue.navMove.path));
    } catch (e) {
      log('SoundController: Error playing compass move: $e');
    }
  }

  Future<void> stopAll() async {
    try {
      await _primaryPlayer.stop();
      await _navPlayer.stop();
    } catch (e) {
      log('SoundController: Error stopping audio: $e');
    }
  }

  void dispose() {
    _primaryPlayer.dispose();
    _navPlayer.dispose();
  }
}

extension SoundContextX on BuildContext {
  SoundController get sounds => SoundController.instance;

  void playSound(
    SoundCue cue, {
    int floorLevel = 0,
    bool isSettingsFloor = false,
  }) {
    SoundController.instance.play(
      cue,
      floorLevel: floorLevel,
      isSettingsFloor: isSettingsFloor,
    );
  }
}