// lib/vision/view/vision_floor_1_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/preferences/preferences.dart'; // 👈 تم التصحيح

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// واجهة الطابق الأول لغرفة الرؤية (Floor 1: AI Vision Tuning & Inspection Detail)
class VisionFloor1View extends StatelessWidget {
  const VisionFloor1View({super.key});

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
                              Icons.remove_red_eye_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI VISION TUNING',
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
                          'Floor 1 • Gemini 2.0 verbosity, auto-flashlight & currency.',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scene Inspection Detail',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Concise (1-2 sentences) or Detailed (layout, hazards, and distances).',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: state.visionInspectionDetail,
                              dropdownColor: colors.surface,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'concise',
                                  child: Text('Concise Summary (Fast)'),
                                ),
                                DropdownMenuItem(
                                  value: 'detailed',
                                  child: Text('Deep Spatial Inspection'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  cubit.setVisionInspectionDetail(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Flashlight in Dark Scenes',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Momentarily fire torch during camera snapshot if lighting is low.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: colors.primary,
                          value: state.autoFlashlightInDark,
                          onChanged: cubit.toggleAutoFlashlight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preferred Currency Identifier',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prioritizes recognition format for specific banknotes.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: state.preferredCurrency,
                              dropdownColor: colors.surface,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'USD / Local',
                                  child: Text('USD / Global Local'),
                                ),
                                DropdownMenuItem(
                                  value: 'EUR',
                                  child: Text('EUR (€)'),
                                ),
                                DropdownMenuItem(
                                  value: 'GBP',
                                  child: Text('GBP (£)'),
                                ),
                                DropdownMenuItem(
                                  value: 'SAR / AED',
                                  child: Text('SAR / AED (ريال/درهم)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  cubit.setPreferredCurrency(val);
                                }
                              },
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
typedef SettingsVisionRoom = VisionFloor1View;