// lib/mobile/perimeter/view/perimeter_floor_1_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/perimeter/cubit/perimeter_cubit.dart';
import 'package:beacon_os/mobile/perimeter/cubit/perimeter_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// واجهة الطابق الأول لغرفة المحيط الأمني (Floor 1: Perimeter Camera Tuning)
class PerimeterFloor1View extends StatelessWidget {
  const PerimeterFloor1View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<PerimeterCubit, PerimeterState>(
          builder: (context, state) {
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
                              Icons.camera_outdoor_rounded,
                              color: colors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PERIMETER TUNING',
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
                          'Floor 1 • Motion sensitivity, offline modes & camera toggles.',
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
                            'AI Scene Analysis on Ring',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Automatically capture and analyze snapshot using Gemini 2.0 when doorbell rings.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          activeColor: colors.primary,
                          value: true, // افتراضي للتجربة
                          onChanged: (val) {},
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.settings_input_antenna_rounded,
                                    color: colors.onSurfaceVariant, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ACTIVE CAMERA SENSORS',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...state.devices.map((device) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    device.label,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    device.isOnline ? 'Online • Motion Active' : 'Offline',
                                    style: TextStyle(
                                      color: device.isOnline ? Colors.green : colors.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  activeColor: colors.primary,
                                  value: device.isMotionEnabled,
                                  onChanged: (val) {
                                    // مكان تنفيذ تحديث حالة الكاميرا في الخزنة
                                  },
                                ),
                              );
                            }),
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