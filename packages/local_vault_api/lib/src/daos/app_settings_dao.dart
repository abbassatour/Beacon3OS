// packages/local_vault_api/lib/src/daos/app_settings_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';
import 'package:local_vault_api/src/migrations/database_migrations.dart';

class AppSettingsDao extends DatabaseAccessor<AppDatabase> {
  AppSettingsDao(super.db);

  static const String defaultSettingsId = DatabaseMigrations.defaultSettingsId;

  Stream<AppSetting> watchSettings() => (select(attachedDatabase.appSettings)
        ..where((s) => s.id.equals(defaultSettingsId)))
      .watchSingle();

  Future<bool> hasCompletedOnboarding() async {
    final settings = await getSettings();
    return settings.hasCompletedOnboarding;
  }

  Future<void> completeOnboarding({
    required String persona,
    required bool isHighContrast,
    required double speechRate,
    bool? spatialWhisperEnabled,
  }) async {
    // 🌟 تفعيل الهمس تلقائياً إذا كان المستخدم كفيفاً، وإطفاؤه إن كان مينيماليست
    final whisper = spatialWhisperEnabled ?? (persona == 'blind_accessible');

    await updateSettings(
      AppSettingsCompanion(
        userPersona: Value(persona),
        hasCompletedOnboarding: const Value(true),
        isHighContrast: Value(isHighContrast),
        speechRate: Value(speechRate),
        spatialWhisperEnabled: Value(whisper),
      ),
    );
  }

  Future<AppSetting> getSettings() async {
    final existing = await (select(attachedDatabase.appSettings)
          ..where((s) => s.id.equals(defaultSettingsId)))
        .getSingleOrNull();

    if (existing != null) return existing;

    final nowUtc = DateTime.now().toUtc();
    await into(attachedDatabase.appSettings).insert(
      AppSettingsCompanion.insert(
        id: defaultSettingsId,
        updatedAt: Value(nowUtc),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    return (select(attachedDatabase.appSettings)
          ..where((s) => s.id.equals(defaultSettingsId)))
        .getSingle();
  }

  Future<void> updateSettings(AppSettingsCompanion updated) {
    return (update(attachedDatabase.appSettings)
          ..where((s) => s.id.equals(defaultSettingsId)))
        .write(
      updated.copyWith(
        updatedAt: Value(DateTime.now().toUtc()),
        isSynced: const Value(false),
      ),
    );
  }
}