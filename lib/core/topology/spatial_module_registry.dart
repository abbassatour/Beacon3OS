// lib/core/topology/spatial_module_registry.dart
import 'dart:developer';
import 'package:beacon_os/core/topology/spatial_module.dart';

/// السجل المركزي الموحد للموديولات والغرف في نظام BeaconOS (Micro-Kernel Module Registry)
class SpatialModuleRegistry {
  SpatialModuleRegistry._();

  /// النسخة المفردة الحصرية للسجل في كامل النظام (Singleton)
  static final SpatialModuleRegistry instance = SpatialModuleRegistry._();

  final Map<String, SpatialModule> _modules = {};

  /// تسجيل موديول جديد في النظام
  void register(SpatialModule module) {
    if (_modules.containsKey(module.id)) {
      log('SpatialModuleRegistry: Module [${module.id}] is already registered. Updating definition.');
    }
    _modules[module.id] = module;
    log('SpatialModuleRegistry: Registered module [${module.id}] ("${module.title}").');
  }

  /// تسجيل قائمة موديولات دفعة واحدة
  void registerAll(Iterable<SpatialModule> modules) {
    for (final module in modules) {
      register(module);
    }
  }

  /// إلغاء تسجيل موديول
  void unregister(String moduleId) {
    _modules.remove(moduleId);
    log('SpatialModuleRegistry: Unregistered module [$moduleId].');
  }

  /// جلب الموديول عبر معرّفه الفريد
  SpatialModule? get(String moduleId) => _modules[moduleId];

  /// التحقق من وجود موديول مسجل
  bool has(String moduleId) => _modules.containsKey(moduleId);

  /// جميع الموديولات المسجلة حالياً
  List<SpatialModule> get allModules => List.unmodifiable(_modules.values);

  /// مسح السجل بالكامل (مفيد للاختبارات المعزولة)
  void clear() {
    _modules.clear();
  }
}