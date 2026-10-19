// lib/mobile/vision/view/vision_floor_neg1_view.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق السفلي للرؤية (Floor -1: Vision & OCR Historical Archive)
class VisionFloorNeg1View extends StatelessWidget {
  const VisionFloorNeg1View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settingsRepo = context.read<SettingsRepository>();
    final taskRepo = context.read<TaskAgendaRepository>();
    final assistant = context.read<AssistantRepository>();
    final shellCubit = context.read<SpatialShellCubit>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ==========================================
            // 1. رأس الصفحة والملاحة الفضائية
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_edu_rounded,
                              color: colors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'VISION & OCR ARCHIVE',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface,
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.outline),
                          ),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                          tooltip: 'Ascend to Ground Floor (AI Vision)',
                          onPressed: shellCubit.returnToGroundFloor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor -1 • Past camera inspections, read documents, currency records & Arbitrum impact.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 2. بطاقة رعاية الصندوق الاجتماعي (Arbitrum Subsidized)
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.green.withValues(alpha: 0.12),
                        child: const Icon(Icons.verified_rounded, color: Colors.green, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VERIFIED AI IMPACT ARCHIVE',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Every camera scan is 100% subsidized by the Community Impact Pool on Arbitrum Sepolia L2.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 3. سجل الفحوصات البصرية المحفوظة
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PAST VISUAL INSPECTIONS',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Icon(Icons.camera_alt_outlined, size: 16, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<VisionScanRecord>>(
              stream: settingsRepo.watchVisionScans(limit: 40),
              builder: (context, snapshot) {
                final scans = snapshot.data ?? [];

                if (scans.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.visibility_off_outlined, size: 36, color: colors.primary),
                            const SizedBox(height: 10),
                            Text(
                              'No Vision Scans Logged Yet',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Inspections performed in AI Vision Studio on Floor 0 will automatically be archived here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final scan = scans[index];
                        final timeStr = DateFormat('MMM d, yyyy • h:mm a').format(scan.createdAt.toLocal());
                        final modeIcon = _getIconForMode(scan.mode);
                        final modeTitle = _getTitleForMode(scan.mode);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                HapticManager.instance.selectionClick();
                                await SoundController.instance.play(SoundCue.navCenter);
                                await assistant.speak(scan.description);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(modeIcon, size: 18, color: colors.primary),
                                            const SizedBox(width: 8),
                                            Text(
                                              modeTitle,
                                              style: TextStyle(
                                                color: colors.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      scan.description,
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 13.5,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: colors.onSurface,
                                            side: BorderSide(color: colors.outline),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.volume_up_rounded, size: 15),
                                          label: const Text('Read Aloud', style: TextStyle(fontSize: 11.5)),
                                          onPressed: () async {
                                            await assistant.speak(scan.description);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: colors.onSurface,
                                            side: BorderSide(color: colors.outline),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.bookmark_add_rounded, size: 15),
                                          label: const Text('Save to Notes', style: TextStyle(fontSize: 11.5)),
                                          onPressed: () async {
                                            await taskRepo.createMemo(
                                              title: 'Vision Archive: $modeTitle',
                                              content: scan.description,
                                            );
                                            await HapticManager.instance.successNotification();
                                            await SoundController.instance.play(SoundCue.success);
                                            await assistant.speak('Saved to notes.');
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: scans.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  IconData _getIconForMode(String mode) {
    switch (mode) {
      case 'textReader':
        return Icons.document_scanner_rounded;
      case 'currency':
        return Icons.payments_rounded;
      case 'productExpiry':
        return Icons.qr_code_scanner_rounded;
      default:
        return Icons.explore_rounded;
    }
  }

  String _getTitleForMode(String mode) {
    switch (mode) {
      case 'textReader':
        return 'DOCUMENT READ';
      case 'currency':
        return 'CURRENCY IDENTIFIED';
      case 'productExpiry':
        return 'PRODUCT INSPECTION';
      default:
        return 'SURROUNDINGS SCAN';
    }
  }
}