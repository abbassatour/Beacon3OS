// lib/mobile/cockpit/view/cockpit_floor_neg1_view.dart
import 'dart:async';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق السفلي لقمرة القيادة (Floor -1: Mesh Hub & Connected Devices)
class CockpitFloorNeg1View extends StatefulWidget {
  const CockpitFloorNeg1View({super.key});

  @override
  State<CockpitFloorNeg1View> createState() => _CockpitFloorNeg1ViewState();
}

class _CockpitFloorNeg1ViewState extends State<CockpitFloorNeg1View> {
  bool _isLocatingPhone = false;

  Future<void> _pingDevice(BuildContext context, String deviceLabel) async {
    setState(() => _isLocatingPhone = true);
    HapticManager.instance.selectionClick();
    await SoundController.instance.play(SoundCue.wake);

    try {
      final assistant = context.read<AssistantRepository>();
      await assistant.speak('Pinging hardware siren and strobe on $deviceLabel.');

      // ✅ الاعتماد على SafetyRadarRepository لإطلاق صفارة الإنذار ووميض الكشاف
      final safetyRadar = context.read<SafetyRadarRepository>();
      await safetyRadar.executeLocateDevice(pulseCycles: 6);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLocatingPhone = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final web3 = Web3Service.instance;
    // ✅ الاعتماد على VaultSyncCoordinator لمتابعة حالة الشبكة وأجهزة الـ Mesh
    final vaultSync = context.read<VaultSyncCoordinator>();
    final launcherRepo = context.read<LauncherRepository>();
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
                              Icons.hub_rounded,
                              color: colors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'MESH HUB & VAULT',
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
                          tooltip: 'Ascend to Ground Floor (Cockpit)',
                          onPressed: shellCubit.returnToGroundFloor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor -1 • Zero-Latency Local Mesh, Living Room Bridges & Master Node.',
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
            // 2. بطاقة العقدة السيادية الرئيسية (This Device)
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _buildCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'THIS MASTER HOST NODE',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          StreamBuilder<SyncTransportMode>(
                            stream: vaultSync.transportModeStream,
                            initialData: vaultSync.currentTransportMode,
                            builder: (context, snapshot) {
                              final mode = snapshot.data ?? SyncTransportMode.discovering;
                              return _buildTransportBadge(mode, colors);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MASTER DID WALLET',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  web3.walletAddressHex,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copy DID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: web3.walletAddressHex));
                              HapticManager.instance.selectionClick();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Master DID copied to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 3. أجهزة العرض وشاشات المنزل المكتشفة (Living Room Displays)
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVE MESH PEERS (LOCAL WI-FI)',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Icon(Icons.wifi_tethering_rounded, size: 16, color: Colors.green),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<LocalNodeInfo>>(
                  stream: vaultSync.activeMeshNodesStream,
                  initialData: vaultSync.activeMeshNodes,
                  builder: (context, snapshot) {
                    final peers = snapshot.data ?? [];

                    if (peers.isEmpty) {
                      return _buildCard(
                        context,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.wifi_find_rounded, color: colors.primary, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Listening for Nearby Screens...',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fire TV and Desktop command centers on this Wi-Fi will appear here (< 2ms).',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: peers.map((peer) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildCard(
                            context,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                                  child: Icon(
                                    peer.deviceType == 'fire_tv'
                                        ? Icons.tv_rounded
                                        : Icons.desktop_windows_rounded,
                                    color: Colors.green,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            peer.deviceType.toUpperCase().replaceAll('_', ' '),
                                            style: TextStyle(
                                              color: colors.onSurface,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              '< 2ms LAN',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'IP: ${peer.ip}:${peer.port}',
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.surface,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.cell_tower_rounded, size: 16),
                                  label: const Text('Ping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => _pingDevice(context, peer.deviceType),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),

            // ==========================================
            // 4. مستشعرات الكاميرات المحيطية (Ring Sensors)
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'PERIMETER HARDWARE NODES (RING)',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<List<RingDeviceEntity>>(
                  stream: launcherRepo.ring.watchDevices(),
                  builder: (context, snapshot) {
                    final devices = snapshot.data ?? [];
                    if (devices.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: devices.map((device) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: _buildCard(
                            context,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: colors.surface,
                                  child: Icon(
                                    Icons.videocam_rounded,
                                    color: device.isOnline ? Colors.green : colors.error,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    device.label,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${device.batteryLevel}% Battery',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportBadge(SyncTransportMode mode, ColorScheme colors) {
    String label;
    Color color;

    switch (mode) {
      case SyncTransportMode.lanDirect:
        label = 'LAN DIRECT';
        color = Colors.green;
        break;
      case SyncTransportMode.cloudRelay:
        label = 'CLOUD RELAY';
        color = colors.primary;
        break;
      case SyncTransportMode.discovering:
        label = 'SCANNING...';
        color = colors.secondary;
        break;
      case SyncTransportMode.standalone:
        label = 'STANDALONE';
        color = colors.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
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
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}