// lib/desktop/settings/widgets/device_pairing_card.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DevicePairingCard extends StatefulWidget {
  const DevicePairingCard({super.key});

  @override
  State<DevicePairingCard> createState() => _DevicePairingCardState();
}

class _DevicePairingCardState extends State<DevicePairingCard> {
  final TextEditingController _codeInputController = TextEditingController();
  bool _isLinked = false;
  String? _linkedVaultId;
  String? _generatedPairingCode;
  bool _isBusy = false;
  String? _syncStatusMessage;

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<SyncTransportMode>? _transportSub;
  StreamSubscription<List<LocalNodeInfo>>? _peersSub;
  SyncTransportMode _transportMode = SyncTransportMode.discovering;
  List<LocalNodeInfo> _activePeers = [];

  @override
  void initState() {
    super.initState();
    _initDesktopHybrid();
  }

  Future<void> _initDesktopHybrid() async {
    final commsRepo = context.read<CommsRepository>();
    await commsRepo.initializeHybridTransport(deviceType: 'desktop');

    _transportMode = commsRepo.currentTransportMode;
    _transportSub?.cancel();
    _transportSub = commsRepo.transportModeStream.listen((mode) {
      if (mounted) setState(() => _transportMode = mode);
    });

    _activePeers = commsRepo.activeMeshNodes;
    _peersSub?.cancel();
    _peersSub = commsRepo.activeMeshNodesStream.listen((peers) {
      if (mounted) setState(() => _activePeers = peers);
    });

    final isLinked = await commsRepo.isDeviceLinked();
    final vaultId = await commsRepo.getLinkedVaultId();

    if (mounted) {
      setState(() {
        _isLinked = isLinked;
        _linkedVaultId = vaultId;
      });
    }
  }

  /// 🚀 سحب وتسوية بيانات الخزنة بالكامل فور نجاح الاقتران
  Future<void> _hydrateVaultAfterPairing(String vaultId) async {
    if (!mounted) return;
    setState(() {
      _isBusy = true;
      _syncStatusMessage = 'Hydrating tasks, notes & spatial canvas...';
    });

    final commsRepo = context.read<CommsRepository>();
    final launcherRepo = context.read<LauncherRepository>();

    try {
      // 1. طلب لقطة مباشرة عبر LAN P2P إن وجد اتصال محلي (< 2ms)
      unawaited(
        commsRepo.requestVaultSnapshot().catchError((Object e) {
          log('DevicePairingCard: LAN snapshot request note: $e');
        }),
      );

      // 2. سحب البيانات الشاملة من السحابة لملء الجداول محلياً في SQLite
      await launcherRepo.restoreVaultFromCloud();
      log('DevicePairingCard: ✅ Successfully restored vault data from cloud.');
    } catch (e) {
      log('DevicePairingCard: Hydration error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _syncStatusMessage = null;
        });
      }
    }
  }

  Future<void> _startPairingDisplaySession() async {
    _authSubscription?.cancel();
    setState(() => _isBusy = true);

    final commsRepo = context.read<CommsRepository>();
    final previousCode = _generatedPairingCode;

    final code = await commsRepo.initiateDevicePairing(
      deviceType: 'desktop',
      previousCode: previousCode,
    );

    if (!mounted) return;

    if (code != null) {
      setState(() {
        _generatedPairingCode = code;
        _isBusy = false;
      });

      _authSubscription = commsRepo
          .listenForDeviceAuthorization(code, deviceType: 'desktop')
          .listen((vaultId) async {
        if (!mounted) return;
        if (vaultId != null && vaultId.isNotEmpty) {
          SoundController.instance.play(SoundCue.success);
          setState(() {
            _isLinked = true;
            _linkedVaultId = vaultId;
            _generatedPairingCode = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Desktop linked! Hydrating vault data across devices...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // ⚡ السحب الفوري للبيانات من الهاتف والسحابة
          await _hydrateVaultAfterPairing(vaultId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vault data fully synchronized!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      });
    } else {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _cancelPairingDisplaySession() async {
    _authSubscription?.cancel();
    final codeToCancel = _generatedPairingCode;
    setState(() => _generatedPairingCode = null);

    if (codeToCancel != null && mounted) {
      final commsRepo = context.read<CommsRepository>();
      await commsRepo.initiateDevicePairing(
        deviceType: 'desktop',
        previousCode: codeToCancel,
      );
    }
  }

  Future<void> _claimRemoteCode() async {
    final clean = _codeInputController.text.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    final commsRepo = context.read<CommsRepository>();
    final sovereignDid = Web3Service.instance.walletAddressHex.toLowerCase();

    final success = await commsRepo.authorizePairingCode(
      clean,
      customVaultId: sovereignDid,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (success) {
      SoundController.instance.play(SoundCue.success);
      _codeInputController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully paired code $clean! Syncing vault...'),
          backgroundColor: Colors.green,
        ),
      );
      await _initDesktopHybrid();
      await _hydrateVaultAfterPairing(sovereignDid);
    } else {
      SoundController.instance.play(SoundCue.error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pairing failed. The code may be expired or incorrect.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pingDevice(String targetLabel) async {
    final commsRepo = context.read<CommsRepository>();
    await SoundController.instance.play(SoundCue.wake);
    await commsRepo.requestLocatePhone(reason: 'Desktop Command Center Ping');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ping siren dispatched to $targetLabel over LAN (< 2ms)!'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  Future<void> _unpair() async {
    _authSubscription?.cancel();
    final commsRepo = context.read<CommsRepository>();
    await commsRepo.unpairDevice();

    if (mounted) {
      setState(() {
        _isLinked = false;
        _linkedVaultId = null;
        _generatedPairingCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device unlinked from phone vault.')),
      );
      await _initDesktopHybrid();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _transportSub?.cancel();
    _peersSub?.cancel();
    _codeInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SettingsCard(
      title: 'DEVICE PAIRING & LIVING ROOM RELAY (P2P)',
      icon: Icons.wifi_tethering_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Relay Mode Status:',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildTransportIndicator(colors),
            ],
          ),
          const SizedBox(height: 12),
          if (_syncStatusMessage != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _syncStatusMessage!,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_isLinked) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LINKED TO MASTER PHONE VAULT',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _linkedVaultId ?? 'Remote Sovereign Node',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: const Text('Unpair', style: TextStyle(fontSize: 12)),
                    onPressed: _unpair,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Pair seamlessly with your Beacon Phone or Fire TV living room display without emails or passwords:',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            if (_generatedPairingCode != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.primary, width: 1.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SPEAK TO BEACON PHONE:',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '"Pair ${_generatedPairingCode!.substring(0, 3)} ${_generatedPairingCode!.substring(3, 6)}"',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Generate new code',
                          onPressed: _startPairingDisplaySession,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Cancel',
                          onPressed: _cancelPairingDisplaySession,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.primary),
                        foregroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_rounded, size: 18),
                      label: const Text(
                        'Show Code to Link Phone',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: _isBusy ? null : _startPairingDisplaySession,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeInputController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter 6-digit code from TV (e.g. 849201)',
                      filled: true,
                      fillColor: context.scaffoldBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                  onPressed: _isBusy ? null : _claimRemoteCode,
                  child: const Text('Authorize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],

          // ==========================================
          // 📡 قائمة أجهزة الـ LAN Mesh النشطة
          // ==========================================
          if (_activePeers.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DISCOVERED MESH NODES (${_activePeers.length})',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const Icon(Icons.wifi_tethering_rounded, size: 15, color: Colors.green),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: _activePeers.map((peer) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: Icon(
                          peer.deviceType == 'fire_tv'
                              ? Icons.tv_rounded
                              : (peer.deviceType == 'phone'
                                  ? Icons.phone_android_rounded
                                  : Icons.desktop_windows_rounded),
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              peer.deviceType.toUpperCase().replaceAll('_', ' '),
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${peer.ip}:${peer.port}',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          side: BorderSide(color: colors.primary),
                        ),
                        icon: Icon(Icons.cell_tower_rounded, size: 14, color: colors.primary),
                        label: Text('Ping', style: TextStyle(fontSize: 11, color: colors.primary)),
                        onPressed: () => _pingDevice(peer.deviceType),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransportIndicator(ColorScheme colors) {
    String label;
    Color color;
    IconData icon;

    switch (_transportMode) {
      case SyncTransportMode.lanDirect:
        label = 'LAN DIRECT (< 2ms)';
        color = Colors.green;
        icon = Icons.bolt_rounded;
        break;
      case SyncTransportMode.cloudRelay:
        label = 'CLOUD RELAY';
        color = colors.primary;
        icon = Icons.cloud_done_rounded;
        break;
      case SyncTransportMode.discovering:
        label = 'SCANNING LAN...';
        color = colors.secondary;
        icon = Icons.wifi_find_rounded;
        break;
      case SyncTransportMode.standalone:
        label = 'STANDALONE';
        color = colors.onSurfaceVariant;
        icon = Icons.wifi_off_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}