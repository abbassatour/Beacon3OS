// lib/cockpit/view/cockpit_floor_1_view.dart
import 'package:beacon_os/auth/cubit/auth_cubit.dart';
import 'package:beacon_os/auth/cubit/auth_state.dart';
import 'package:beacon_os/auth/view/login_page.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/preferences/preferences.dart'; // 👈 تم التصحيح

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق الأول لقمرة القيادة (Floor 1: Core Engine & System Preferences)
class CockpitFloor1View extends StatelessWidget {
  const CockpitFloor1View({super.key});

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
                            Icon(Icons.tune_rounded, color: colors.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'CORE ENGINE PREFERENCES',
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
                          'Floor 1 • Cloud Vault, Sound, Haptics, and Display tuning.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildAccountVaultCard(context),
                      const SizedBox(height: 14),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'High Contrast OLED Theme',
                            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Ultra-pure pitch black with neon cyan and yellow.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                          activeColor: colors.primary,
                          value: state.isHighContrast,
                          onChanged: (val) {
                            cubit.toggleHighContrast(val);
                            context.read<ThemeCubit>().toggleTheme(isHighContrast: val);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Tactile Haptic Feedback',
                            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Physical vibrations when moving between rooms and tapping canvas.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                          activeColor: colors.primary,
                          value: state.hapticsEnabled,
                          onChanged: cubit.toggleHaptics,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Spatial Audio Cues',
                            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Chimes and spatial frequencies when panning compass coordinates.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                          activeColor: colors.primary,
                          value: state.soundCuesEnabled,
                          onChanged: cubit.toggleSoundCues,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Voice Reading Speed',
                                  style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${(state.speechRate * 2).toStringAsFixed(1)}x',
                                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              min: 0.3,
                              max: 1.0,
                              divisions: 14,
                              activeColor: colors.primary,
                              inactiveColor: colors.outline,
                              value: state.speechRate.clamp(0.3, 1.0),
                              onChanged: cubit.setSpeechRate,
                            ),
                          ],
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

  Widget _buildAccountVaultCard(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isAuthenticated =
            authState.isAuthenticated && authState.user != null;
        final userEmail = authState.user?.email ?? 'Connected User';

        return Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isAuthenticated ? colors.primary : colors.outline,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: (isAuthenticated
                              ? colors.primary
                              : colors.secondary)
                          .withValues(alpha: 0.15),
                      child: Icon(
                        isAuthenticated
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_queue_rounded,
                        color: isAuthenticated ? colors.primary : colors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuthenticated
                                ? 'CLOUD VAULT ACTIVE'
                                : 'LOCAL OFFLINE VAULT',
                            style: TextStyle(
                              color: isAuthenticated
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAuthenticated
                                ? userEmail
                                : 'Sync tasks & radar across devices',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isAuthenticated
                      ? 'Your tasks, scheduled alarms, and emergency contacts are continuously backed up to your encrypted Supabase vault.'
                      : 'Your data is currently stored only on this device. Sign in or register to enable real-time cloud backup.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                if (!isAuthenticated)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Sign In / Link Cloud Vault',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: () {
                        HapticManager.instance.selectionClick();
                        Navigator.of(context).push(LoginPage.route());
                      },
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.sync_rounded, size: 16, color: colors.primary),
                        label: Text(
                          'Sync Now',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () async {
                          HapticManager.instance.selectionClick();
                          final repo = context.read<LauncherRepository>();
                          await repo.syncPendingOfflineChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Vault synced with Supabase!'),
                                backgroundColor: colors.primary,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(
                            color: colors.error.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () => _confirmSignOut(context),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context) {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outline),
        ),
        title: Text(
          'Sign Out of Cloud Vault?',
          style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your local data will remain safe on this device, but real-time cloud synchronization will pause.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.surface,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthCubit>().signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
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

// 🛡️ توافق عكسي مع الكود القديم
typedef SettingsCoreRoom = CockpitFloor1View;