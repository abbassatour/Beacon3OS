// packages/launcher_repository/lib/src/domains/ring_repository.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:launcher_repository/src/domains/assistant_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:ring_integration_api/ring_integration_api.dart';

export 'package:ring_integration_api/ring_integration_api.dart'
    show
        RingCameraLocation,
        RingDevice,
        RingDeviceType,
        RingEvent,
        RingEventType,
        RingScenarioPreset;

/// العقد النطاقي المخصص لإدارة كاميرات Ring المحيطية وأحداثها
abstract class RingRepository {
  /// تدفق قائمة الأجهزة المسجلة في الخزنة
  Stream<List<RingDeviceEntry>> watchDevices();

  /// تدفق سجل الأحداث الأمنية والتنبيهات
  Stream<List<RingEventEntry>> watchRecentEvents({int limit = 30});

  /// تدفق الأحداث الحية الواردة فوراً من العتاد أو المحاكي
  Stream<RingEvent> get liveEventsStream;

  /// جلب جميع الكاميرات لمرة واحدة
  Future<List<RingDeviceEntry>> getAllDevices();

  /// جلب كاميرا محددة بالمعرف
  Future<RingDeviceEntry?> getDeviceById(String id);

  /// فحص مباشر للكاميرا بالصوت وتحليل المشهد عبر Gemini 2.0 Flash
  Future<String?> inspectCameraLive({
    required String deviceId,
    String? customQuery,
  });

  /// فتح قناة التحدث الصوتي ثنائي الاتجاه
  Future<void> answerDoorbell(String deviceId);

  /// إطلاق سيناريو محاكاة اختباري للمحكمين
  Future<void> triggerSimulatedScenario(RingScenarioPreset scenario);

  /// تعليم حدث أمني كمقروء
  Future<void> markEventAsRead(String eventId);

  /// تحرير الموارد
  void dispose();
}

/// التنفيذ الفعلي لـ RingRepository المدمج مع قاعدة بيانات Drift والذكاء الاصطناعي
class RingRepositoryImpl implements RingRepository {
  RingRepositoryImpl({
    required AppDatabase database,
    required RingClientInterface ringClient,
    required AssistantRepository assistantRepository,
    CloudSyncClient? cloudSync,
  })  : _db = database,
        _ringClient = ringClient,
        _assistant = assistantRepository,
        _cloud = cloudSync {
    _initEventPipeline();
  }

  final AppDatabase _db;
  final RingClientInterface _ringClient;
  final AssistantRepository _assistant;
  final CloudSyncClient? _cloud;

  StreamSubscription<RingEvent>? _ringEventsSubscription;
  final StreamController<RingEvent> _liveEventsController =
      StreamController<RingEvent>.broadcast();

  @override
  Stream<RingEvent> get liveEventsStream => _liveEventsController.stream;

  @override
  Stream<List<RingDeviceEntry>> watchDevices() => _db.watchAllRingDevices();

  @override
  Stream<List<RingEventEntry>> watchRecentEvents({int limit = 30}) =>
      _db.watchRecentRingEvents(limit: limit);

  @override
  Future<List<RingDeviceEntry>> getAllDevices() => _db.getAllRingDevices();

  @override
  Future<RingDeviceEntry?> getDeviceById(String id) =>
      _db.getRingDeviceById(id);

  /// 🤖 الأنبوب التلقائي للذكاء الاصطناعي (Autonomous AI Vision & Audio Pipeline)
  void _initEventPipeline() {
    _ringEventsSubscription = _ringClient.eventsStream.listen((event) async {
      log('RingRepository: 🔔 Inbound event [${event.type.name}] from [${event.deviceLabel}]');

      // 1. تحديث تاريخ آخر نشاط للجهاز في قاعدة البيانات
      await _db.updateRingDeviceActivity(
        id: event.deviceId,
        lastDingAt: event.type == RingEventType.ding ? event.timestamp : null,
        lastMotionAt:
            event.type == RingEventType.motion ? event.timestamp : null,
      );

      // 2. تحليل لقطة الكاميرا فوراً عبر Gemini 2.0 Flash إن لم يكن الوصف جاهزاً
      String description = event.aiSceneDescription ?? '';
      if (description.isEmpty && event.snapshotBase64.isNotEmpty) {
        try {
          final prompt =
              'You are the digital eyes for a blind homeowner. An event occurred at the ${event.deviceLabel}. '
              'In 1 to 2 clear sentences, describe who is there, if any parcel/vehicle is present, and immediate security context.';

          description = await _assistant.analyzeVisionFrame(
            base64Image: event.snapshotBase64,
            prompt: prompt,
          );
        } catch (e) {
          log('RingRepository: AI analysis fallback: $e');
          description = 'Activity detected at ${event.deviceLabel}.';
        }
      }

      // 3. حفظ الحدث موثقاً بالوصف الذكي في الخزنة المشفرة
      await _db.insertRingEvent(
        RingEventsCompanion.insert(
          id: event.id,
          deviceId: event.deviceId,
          deviceLabel: event.deviceLabel,
          eventType: event.type.name,
          timestamp: Value(event.timestamp),
          aiSceneDescription: Value(description),
          isRead: const Value(false),
        ),
      );

      // 4. إشعار الواجهات وشاشات المعيشة (Fire TV / Dashboard)
      final enrichedEvent = event.copyWith(aiSceneDescription: description);
      _liveEventsController.add(enrichedEvent);

      // 5. النطق الصوتي الفوري للمكفوفين عبر محرك TTS
      final alertPrefix = event.type == RingEventType.ding
          ? 'Doorbell ding at ${event.deviceLabel}: '
          : 'Motion alert at ${event.deviceLabel}: ';

      await _assistant.speak('$alertPrefix$description');
    });
  }

  @override
  Future<String?> inspectCameraLive({
    required String deviceId,
    String? customQuery,
  }) async {
    final device = await _db.getRingDeviceById(deviceId);
    final label = device?.label ?? 'Security Camera';

    final snapshotBase64 = await _ringClient.captureSnapshotBase64(deviceId);
    if (snapshotBase64 == null || snapshotBase64.isEmpty) {
      const errorMsg = 'Could not retrieve camera video feed.';
      await _assistant.speak(errorMsg);
      return errorMsg;
    }

    final prompt = customQuery ??
        'You are the digital eyes for a blind person looking at the $label feed. '
        'Describe the live view clearly in 1 or 2 sentences: who is visible, ground obstacles, or vehicles.';

    final analysis = await _assistant.analyzeVisionFrame(
      base64Image: snapshotBase64,
      prompt: prompt,
    );

    await _assistant.speak(analysis);
    return analysis;
  }

  @override
  Future<void> answerDoorbell(String deviceId) async {
    final device = await _db.getRingDeviceById(deviceId);
    final label = device?.label ?? 'Front Door';
    await _ringClient.startTwoWayAudio(deviceId);
    await _assistant.speak('Two-way audio connected to $label. Speak now.');
  }

  @override
  Future<void> triggerSimulatedScenario(RingScenarioPreset scenario) async {
    await _ringClient.triggerSimulatedScenario(scenario);
  }

  @override
  Future<void> markEventAsRead(String eventId) =>
      _db.markRingEventAsRead(eventId);

  @override
  void dispose() {
    _ringEventsSubscription?.cancel();
    _liveEventsController.close();
    _ringClient.dispose();
  }
}