// lib/mobile/perimeter/view/perimeter_floor_0_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/perimeter/cubit/perimeter_cubit.dart';
import 'package:beacon_os/mobile/perimeter/cubit/perimeter_state.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

class PerimeterFloor0View extends StatelessWidget {
  const PerimeterFloor0View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final returnHint = SpatialDirection.south.returnGestureHint;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<PerimeterCubit, PerimeterState>(
          builder: (context, state) {
            final cubit = context.read<PerimeterCubit>();

            if (state.isLoading && state.devices.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMART PERIMETER',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$returnHint or double-tap to return to Cockpit.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.devices.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.devices.length,
                        itemBuilder: (context, index) {
                          final device = state.devices[index];
                          final isSelected = state.selectedDeviceId == device.id;
                          return _buildDeviceChip(
                            context,
                            device,
                            isSelected,
                            () => cubit.selectDevice(device.id),
                          );
                        },
                      ),
                    ),
                  ),
                if (state.selectedDevice != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: _buildActiveDeviceCard(context, state, cubit),
                    ),
                  ),
                if (state.liveInspectionText != null &&
                    state.liveInspectionText!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildLiveInspectionResult(context, state),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'JUDGE DEMO: TRIGGER EVENT',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSimulatorControls(context, cubit),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'RECENT SECURITY EVENTS',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                if (state.recentEvents.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          'No recent activity logged. Perimeter is secure.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = state.recentEvents[index];
                          return _buildEventTile(context, event, cubit);
                        },
                        childCount: state.recentEvents.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeviceChip(
    BuildContext context,
    RingDeviceEntity device,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    IconData icon;
    switch (device.deviceType) {
      case 'doorbell':
        icon = Icons.doorbell_rounded;
        break;
      case 'floodlightCam':
        icon = Icons.light_rounded;
        break;
      case 'indoorCam':
        icon = Icons.videocam_rounded;
        break;
      default:
        icon = Icons.camera_outdoor_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(
          icon,
          color: isSelected ? colors.surface : colors.primary,
          size: 18,
        ),
        label: Text(device.label),
        selected: isSelected,
        selectedColor: colors.primary,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.outline, width: 1.2),
        labelStyle: TextStyle(
          color: isSelected ? colors.surface : colors.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildActiveDeviceCard(
    BuildContext context,
    PerimeterState state,
    PerimeterCubit cubit,
  ) {
    final colors = context.colors;
    final device = state.selectedDevice!;
    final isAnswering = state.isTwoWayAudioActive &&
        state.activeAudioDeviceId == device.id;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isAnswering ? colors.error : colors.outline,
          width: isAnswering ? 2.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAnswering ? colors.error : colors.primary)
                .withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline ? Colors.green : colors.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    device.isOnline ? 'LIVE FEED' : 'OFFLINE',
                    style: TextStyle(
                      color: device.isOnline ? Colors.green : colors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.battery_charging_full_rounded,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${device.batteryLevel}%',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Icon(
            isAnswering ? Icons.mic_rounded : Icons.camera_outdoor_rounded,
            size: 48,
            color: isAnswering ? colors.error : colors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            device.label.toUpperCase(),
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: state.isInspecting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.surface,
                          ),
                        )
                      : const Icon(Icons.remove_red_eye_rounded, size: 20),
                  label: Text(
                    state.isInspecting ? 'Inspecting...' : 'Inspect AI',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: state.isInspecting || isAnswering
                      ? null
                      : () => cubit.inspectCamera(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAnswering ? colors.error : colors.onSurface,
                    side: BorderSide(
                      color: isAnswering ? colors.error : colors.outline,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    isAnswering ? Icons.stop_rounded : Icons.mic_none_rounded,
                    size: 20,
                  ),
                  label: Text(
                    isAnswering ? 'End Audio' : '2-Way Audio',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () {
                    if (isAnswering) {
                      cubit.stopTwoWayAudio();
                    } else {
                      cubit.startTwoWayAudio(device.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveInspectionResult(BuildContext context, PerimeterState state) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI VISION ANALYSIS',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Gemini 2.0',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.liveInspectionText!,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorControls(BuildContext context, PerimeterCubit cubit) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          _buildSimButton(
            context,
            'Simulate Courier at Front Door',
            Icons.local_shipping_rounded,
            () => cubit.triggerScenario(RingScenarioPreset.courierDelivery),
          ),
          const SizedBox(height: 8),
          _buildSimButton(
            context,
            'Simulate Night Prowler in Backyard',
            Icons.pets_rounded,
            () => cubit.triggerScenario(RingScenarioPreset.nightProwler),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSimButton(
                  context,
                  'Baby Waking',
                  Icons.child_care_rounded,
                  () => cubit.triggerScenario(RingScenarioPreset.babyCrying),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSimButton(
                  context,
                  'Car Arriving',
                  Icons.directions_car_rounded,
                  () => cubit.triggerScenario(RingScenarioPreset.carArriving),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.onSurface,
        backgroundColor: colors.surface,
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      icon: Icon(icon, size: 18, color: colors.secondary),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildEventTile(
    BuildContext context,
    RingEventEntity event,
    PerimeterCubit cubit,
  ) {
    final colors = context.colors;
    final isDing = event.eventType == 'ding';
    final iconColor = isDing ? colors.secondary : colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => cubit.readEventAloud(event),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline, width: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: iconColor.withValues(alpha: 0.15),
                  child: Icon(
                    isDing ? Icons.notifications_active_rounded : Icons.directions_run_rounded,
                    color: iconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            event.deviceLabel,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            DateFormat('h:mm a').format(event.timestamp),
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.aiSceneDescription ?? 'Activity detected.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.3,
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
    );
  }
}

/// Standalone Wrapper
class PerimeterFloor0StandaloneView extends StatelessWidget {
  const PerimeterFloor0StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PerimeterCubit(
        ringRepository: context.read<LauncherRepository>().ring,
        assistantRepository: context.read<AssistantRepository>(),
      ),
      child: const PerimeterFloor0View(),
    );
  }
}