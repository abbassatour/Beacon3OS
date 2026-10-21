// lib/mobile/vision/view/vision_floor_0_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/spatial_direction.dart';
import 'package:beacon_os/mobile/vision/cubit/vision_cubit.dart';
import 'package:beacon_os/mobile/vision/cubit/vision_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق الأرضي لاستوديو الرؤية الذكية (Floor 0: AI Vision Studio)
class VisionFloor0View extends StatelessWidget {
  const VisionFloor0View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final returnHint = CompassDirection.east.returnGestureHint;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<VisionCubit, VisionState>(
          builder: (context, state) {
            final cubit = context.read<VisionCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // 1. رأس الصفحة المحمي من الطفح نهائياً
                // ==========================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AI VISION STUDIO',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$returnHint or double-tap to return to Cockpit.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: state.isTorchOn
                              ? colors.secondary
                              : colors.surface,
                          foregroundColor: state.isTorchOn
                              ? colors.surface
                              : colors.onSurface,
                          side: BorderSide(color: colors.outline),
                        ),
                        icon: Icon(state.isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded),
                        tooltip: state.isTorchOn
                            ? 'Turn off flashlight'
                            : 'Turn on flashlight',
                        onPressed: cubit.toggleTorch,
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // 2. شرائح اختيار نمط الفحص (Mode Chips)
                // ==========================================
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildModeChip(
                          context: context,
                          title: 'Surroundings',
                          icon: Icons.explore_rounded,
                          isSelected:
                              state.activeMode == VisionMode.surroundings,
                          onTap: () => cubit.setMode(VisionMode.surroundings),
                        ),
                        _buildModeChip(
                          context: context,
                          title: 'Text / Doc',
                          icon: Icons.document_scanner_rounded,
                          isSelected:
                              state.activeMode == VisionMode.textReader,
                          onTap: () => cubit.setMode(VisionMode.textReader),
                        ),
                        _buildModeChip(
                          context: context,
                          title: 'Currency',
                          icon: Icons.payments_rounded,
                          isSelected: state.activeMode == VisionMode.currency,
                          onTap: () => cubit.setMode(VisionMode.currency),
                        ),
                        _buildModeChip(
                          context: context,
                          title: 'Product / Expiry',
                          icon: Icons.qr_code_scanner_rounded,
                          isSelected:
                              state.activeMode == VisionMode.productExpiry,
                          onTap: () =>
                              cubit.setMode(VisionMode.productExpiry),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==========================================
                // 3. رادار الكاميرا ومستشعر الفحص باللمس
                // ==========================================
                Expanded(
                  child: Semantics(
                    label: state.isSpeaking
                        ? 'AI is describing scene. Tap anywhere on screen to stop reading.'
                        : 'Camera AI Radar. Tap anywhere on screen to capture and scan.',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: cubit.captureAndAnalyze,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildRadarScanner(context, state),
                            const SizedBox(height: 24),
                            Text(
                              _getStatusTitle(state),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.isSpeaking
                                  ? 'Tap anywhere to stop reading'
                                  : (state.isBusy
                                      ? 'Gemini 2.0 Flash is inspecting scene...'
                                      : 'Tap anywhere on screen to scan'),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ==========================================
                // 4. بطاقة نتيجة الفحص الذكية المحمية
                // ==========================================
                if (state.lastSpokenResult.isNotEmpty)
                  Semantics(
                    label:
                        'Last scan result: ${state.lastSpokenResult}. Subsidized on Arbitrum ledger. Replay or save to notes.',
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.outline, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: colors.onSurface.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.remove_red_eye_rounded,
                                        color: colors.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'SCENE DESCRIPTION',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.volume_up_rounded,
                                        color: colors.primary, size: 20),
                                    tooltip: 'Replay Description',
                                    onPressed: cubit.replayDescription,
                                  ),
                                  IconButton(
                                    icon: state.isSavingNote
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colors.primary,
                                            ),
                                          )
                                        : Icon(Icons.bookmark_add_rounded,
                                            color: colors.primary, size: 20),
                                    tooltip: 'Save to Notes',
                                    onPressed: state.isSavingNote
                                        ? null
                                        : cubit.saveScanResultAsNote,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.verified_rounded, size: 12, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Subsidized on Arbitrum Sepolia',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            state.lastSpokenResult,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(
          icon,
          color: isSelected ? colors.surface : colors.primary,
          size: 18,
        ),
        label: Text(title),
        selected: isSelected,
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.outline, width: 1.2),
        labelStyle: TextStyle(
          color: isSelected ? colors.surface : colors.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildRadarScanner(BuildContext context, VisionState state) {
    final colors = context.colors;
    final isBusy = state.isBusy;
    final isSpeaking = state.isSpeaking;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isBusy ? 160 : 130,
      height: isBusy ? 160 : 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.withValues(
          alpha: isBusy ? 0.2 : (isSpeaking ? 0.12 : 0.06),
        ),
        border: Border.all(
          color: isSpeaking ? colors.secondary : colors.primary,
          width: isBusy ? 3.2 : 2.0,
        ),
        boxShadow: [
          if (isBusy || isSpeaking)
            BoxShadow(
              color: (isSpeaking ? colors.secondary : colors.primary)
                  .withValues(alpha: 0.3),
              blurRadius: 24,
              spreadRadius: 4,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          isBusy
              ? Icons.hourglass_top_rounded
              : (isSpeaking
                  ? Icons.volume_up_rounded
                  : Icons.camera_alt_rounded),
          color: isSpeaking ? colors.secondary : colors.primary,
          size: isBusy ? 54 : 48,
        ),
      ),
    );
  }

  String _getStatusTitle(VisionState state) {
    if (state.isSpeaking) return 'DESCRIBING SCENE...';
    if (state.status == VisionStatus.capturing) return 'CAPTURING FRAME...';
    if (state.status == VisionStatus.analyzing) return 'ANALYZING SCENE...';
    switch (state.activeMode) {
      case VisionMode.surroundings:
        return 'INSPECT SURROUNDINGS';
      case VisionMode.textReader:
        return 'READ DOCUMENT';
      case VisionMode.currency:
        return 'IDENTIFY CASH';
      case VisionMode.productExpiry:
        return 'PRODUCT & EXPIRY';
    }
  }
}

/// Standalone Wrapper
class VisionFloor0StandaloneView extends StatelessWidget {
  const VisionFloor0StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VisionCubit(
        assistantRepository: context.read<AssistantRepository>(),
        hardwareRepository: context.read<SystemHardwareRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
        taskRepository: context.read<TaskAgendaRepository>(),
      ),
      child: const VisionFloor0View(),
    );
  }
}