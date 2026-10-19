// lib/desktop/settings/widgets/device_pairing_card.dart
import 'dart:async';
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
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<SyncTransportMode>? _transportSub;
  SyncTransportMode _transportMode = SyncTransportMode.discovering;

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

    final isLinked = await commsRepo.isDeviceLinked();
    final vaultId = await commsRepo.getLinkedVaultId();

    if (mounted) {
      setState(() {
        _isLinked = isLinked;
        _linkedVaultId = vaultId;
      });
    }
  }

  Future<void> _startPairingDisplaySession() async {
    _authSubscription?.cancel();
    setState(() => _isBusy = true);

    final commsRepo = context.read<CommsRepository>();
    final previousCode = _generatedPairingCode;

    // 🛡️ حرق الكود السابق إن وجد وتوليد كود جديد لجهاز سطح المكتب
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

      // 🛡️ تحديد نوع الجهاز بدقة كـ 'desktop' بدلاً من 'fire_tv'
      _authSubscription = commsRepo
          .listenForDeviceAuthorization(code, deviceType: 'desktop')
          .listen((vaultId) {
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
              content: Text('Desktop linked to Beacon phone vault successfully!'),
              backgroundColor: Colors.green,
            ),
          );
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
      // حرق الكود في السحابة لتأمين الجلسة
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
          content: Text('Successfully authorized device pairing for code $clean!'),
          backgroundColor: Colors.green,
        ),
      );
      _initDesktopHybrid();
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

  Future<void> _unpair() async {
    _authSubscription?.cancel();
    final commsRepo = context.read<CommsRepository>();

    // فك الاقتران وتصفير المقابس وحزم الـ UDP في HybridSyncClient
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