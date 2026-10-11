// lib/focus/view/focus_floor_1_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/preferences/preferences.dart'; // 👈 تم التصحيح

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
/// واجهة الطابق الأول لغرفة التركيز (Floor 1: Focus Tuning & Alarm Preferences)
class FocusFloor1View extends StatelessWidget {
  const FocusFloor1View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final cubit = context.read<SettingsCubit>();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'FOCUS & ALARMS TUNING',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Floor 1 • Intervals, halfway chimes, and system clock integration.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Halfway Voice Chime',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Audio announcement when 50% of the focus cycle has passed.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: colors.primary,
                          value: state.voiceChimeHalfway,
                          onChanged: cubit.toggleVoiceChimeHalfway,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Vibrate On Session Finish',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Long calming haptic pulse when Pomodoro session concludes.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: colors.primary,
                          value: state.vibrateOnSessionFinish,
                          onChanged: cubit.toggleVibrateOnFinish,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Sync Alarms with Android Clock',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Set system-level AlarmClock silently in background.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: colors.primary,
                          value: state.syncAlarmsWithAndroidClock,
                          onChanged: cubit.toggleSyncAlarmsWithAndroid,
                        ),
                      ),
                      const SizedBox(height: 60),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outline, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// 🛡️ اسم توافقي لمنع انكسار الكود القديم
typedef SettingsFocusRoom = FocusFloor1View;