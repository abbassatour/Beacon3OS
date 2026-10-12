// packages/local_vault_api/lib/src/tables/spatial_nodes_table.dart
import 'package:drift/drift.dart';

class SpatialNodes extends Table {
  /// المعرف الفريد للغرفة (مثل: 'cockpit', 'focus', 'comms', 'vision', 'agenda')
  TextColumn get id => text()();

  /// معرف الموديول البرمجي المشغل لهذه الغرفة
  TextColumn get moduleId => text()();

  /// رقم الطابق (محور الارتفاع Z: مثلاً 0 للأرضي، 1 للإعدادات، -1 للأرشيف)
  IntColumn get floorLevel => integer().withDefault(const Constant(0))();

  /// الإحداثي الأفقي X (0 في المركز، سالب لليسار، موجب لليمين)
  IntColumn get x => integer().withDefault(const Constant(0))();

  /// الإحداثي الرأسي Y (0 في المركز، موجب للأعلى/الشمال، سالب للأسفل/الجنوب)
  IntColumn get y => integer().withDefault(const Constant(0))();

  /// عنوان مخصص اختياري للغرفة
  TextColumn get customTitle => text().nullable()();

  /// إعدادات مخصصة بصيغة JSON (مثل روابط كاميرات RTSP، معرفات الأجهزة)
  TextColumn get configJson => text().nullable()();

  /// هل الغرفة مفعلة ومرئية في الفضاء؟
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();

  // معايير المزامنة والتتبع
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}