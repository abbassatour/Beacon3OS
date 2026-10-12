// lib/desktop/view/desktop_settings_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_settings_state.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DesktopSettingsView extends StatelessWidget {
  const DesktopSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopSettingsCubit(
        settingsRepository: context.read<SettingsRepository>(),
        taskRepository: context.read<TaskAgendaRepository>(),
        focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
        commsRepository: context.read<CommsRepository>(),
        topologyRepository: context.read<TopologyRepository>(),
      ),
      child: const _DesktopSettingsContent(),
    );
  }
}

class _DesktopSettingsContent extends StatelessWidget {
  const _DesktopSettingsContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopSettingsCubit, DesktopSettingsState>(
      builder: (context, state) {
        if (state.status == DesktopSettingsStatus.loading && state.settings == null) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. رأس الصفحة: العنوان ومؤشر المزامنة
                _SettingsHeader(state: state),
                const SizedBox(height: 20),

                // 2. شبكة البطاقات المنقسمة لعمودين
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // العمود الأيسر: السحابة، هوية النظام، والصوت
                        Expanded(
                          child: Column(
                            children: [
                              _CloudVaultCard(state: state),
                              const SizedBox(height: 16),
                              _PersonaAndThemeCard(state: state),
                              const SizedBox(height: 16),
                              _AudioEngineCard(state: state),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),

                        // العمود الأيمن: تفضيلات الأجندة، التركيز، والرؤية
                        Expanded(
                          child: Column(
                            children: [
                              _AgendaEngineCard(state: state),
                              const SizedBox(height: 16),
                              _FocusEngineCard(state: state),
                              const SizedBox(height: 16),
                              _VisionAndSafetyCard(state: state),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: colors.primary, size: 26),
                const SizedBox(width: 10),
                Text(
                  'VAULT & CLOUD SETTINGS',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bidirectional Supabase sync inspector, user persona manager, and Floor 1 engine controls.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: state.isSyncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.surface),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: Text(
            state.isSyncing ? 'Syncing...' : 'Force Sync All',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: state.isSyncing ? null : cubit.forceFullSync,
        ),
      ],
    );
  }
}

class _CloudVaultCard extends StatelessWidget {
  const _CloudVaultCard({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _SettingsCard(
      title: 'ENCRYPTED CLOUD VAULT',
      icon: Icons.cloud_done_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.isOnline ? Colors.green : Colors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.isOnline ? 'Supabase Sync: Active & Live' : 'Local Offline Vault Mode',
                  style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'User: ${state.userEmail ?? 'Local Offline Guest'}',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          if (state.lastSyncMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.lastSyncMessage!,
                style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonaAndThemeCard extends StatelessWidget {
  const _PersonaAndThemeCard({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();
    final themeCubit = context.read<ThemeCubit>();

    final isBlindMode = state.userPersona == 'blind_accessible';

    return _SettingsCard(
      title: 'SYSTEM PERSONA & DISPLAY',
      icon: Icons.palette_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Interaction Persona',
            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Blind Accessible 👁️')),
                  selected: isBlindMode,
                  onSelected: (val) {
                    if (val) {
                      cubit.setPersona('blind_accessible');
                      cubit.setHighContrast(true);
                      themeCubit.toggleTheme(isHighContrast: true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Digital Minimalist 🧘')),
                  selected: !isBlindMode,
                  onSelected: (val) {
                    if (val) {
                      cubit.setPersona('digital_minimalist');
                      cubit.setHighContrast(false);
                      themeCubit.toggleTheme(isHighContrast: false);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'High Contrast OLED Theme',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Pure black canvas with neon cyan and yellow tokens.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.isHighContrast,
            onChanged: (val) {
              cubit.setHighContrast(val);
              themeCubit.toggleTheme(isHighContrast: val);
            },
          ),
        ],
      ),
    );
  }
}

class _AudioEngineCard extends StatelessWidget {
  const _AudioEngineCard({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return _SettingsCard(
      title: 'AUDIO & FEEDBACK ENGINE',
      icon: Icons.volume_up_rounded,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Spatial Audio Cues', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Harmonic compass chimes when navigating rooms.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.soundCuesEnabled,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(soundCuesEnabled: drift.Value(val))),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Tactile Haptics', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Vibrations on mobile transitions and mic pulses.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.hapticsEnabled,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(hapticsEnabled: drift.Value(val))),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Speech Rate (${(state.speechRate * 2).toStringAsFixed(1)}x)', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(
                width: 140,
                child: Slider(
                  value: state.speechRate.clamp(0.3, 1.0),
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  activeColor: colors.primary,
                  onChanged: cubit.setSpeechRate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgendaEngineCard extends StatelessWidget {
  const _AgendaEngineCard({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return _SettingsCard(
      title: 'AGENDA & TASKS PREFERENCES',
      icon: Icons.calendar_today_rounded,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Default Task Priority', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
              DropdownButton<String>(
                value: state.defaultPriority,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'high', child: Text('🔴 High')),
                  DropdownMenuItem(value: 'medium', child: Text('🟡 Medium')),
                  DropdownMenuItem(value: 'low', child: Text('⚪ Low')),
                ],
                onChanged: (val) {
                  if (val != null) cubit.updateSetting(AppSettingsCompanion(defaultPriority: drift.Value(val)));
                },
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Auto-Archive Completed Priorities', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Instantly hide finished tasks from Cockpit canvas.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.autoArchiveCompleted,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(autoArchiveCompleted: drift.Value(val))),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Speak Due Dates Aloud', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Voice assistant announces relative deadlines on tap.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.speakDueDatesAloud,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(speakDueDatesAloud: drift.Value(val))),
          ),
        ],
      ),
    );
  }
}

class _FocusEngineCard extends StatelessWidget {
  const _FocusEngineCard({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return _SettingsCard(
      title: 'FOCUS & ALARMS PREFERENCES',
      icon: Icons.hourglass_top_rounded,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Halfway Voice Chime', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Voice announcement at 50% mark of focus cycle.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.voiceChimeHalfway,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(voiceChimeHalfway: drift.Value(val))),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Vibrate On Session Finish', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Calming haptic pulse when Pomodoro ends.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.vibrateOnSessionFinish,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(vibrateOnSessionFinish: drift.Value(val))),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Sync Alarms with Android Clock', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Background integration with native AlarmClock.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.primary,
            value: state.syncAlarmsWithAndroidClock,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(syncAlarmsWithAndroidClock: drift.Value(val))),
          ),
        ],
      ),
    );
  }
}

class _VisionAndSafetyCard extends StatelessWidget {
  const _VisionAndSafetyCard({required this.state});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return _SettingsCard(
      title: 'AI VISION & RADAR PREFERENCES',
      icon: Icons.shield_rounded,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vision Inspection Detail', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
              DropdownButton<String>(
                value: state.visionInspectionDetail,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'concise', child: Text('Concise (Fast)')),
                  DropdownMenuItem(value: 'detailed', child: Text('Deep Spatial Inspection')),
                ],
                onChanged: (val) {
                  if (val != null) cubit.updateSetting(AppSettingsCompanion(visionInspectionDetail: drift.Value(val)));
                },
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Auto-Dial Emergency Primary Contact', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Immediately place phone call when SOS triggers.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.error,
            value: state.autoDialEmergency,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(autoDialEmergency: drift.Value(val))),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Share Live GPS on SOS', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Generate Google Maps link for rescue radar.', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
            activeColor: colors.error,
            value: state.shareGpsOnSos,
            onChanged: (val) => cubit.updateSetting(AppSettingsCompanion(shareGpsOnSos: drift.Value(val))),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}