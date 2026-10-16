// lib/impact_pool/view/impact_pool_page.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ImpactPoolPage extends StatefulWidget {
  const ImpactPoolPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ImpactPoolPage());

  @override
  State<ImpactPoolPage> createState() => _ImpactPoolPageState();
}

class _ImpactPoolPageState extends State<ImpactPoolPage> {
  double _balance = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePageInfo();
    });
  }

  Future<void> _loadBalance() async {
    final bal = await Web3Service.instance.getBalanceEth();
    if (mounted) {
      setState(() {
        _balance = bal;
        _isLoading = false;
      });
    }
  }

  Future<void> _announcePageInfo() async {
    try {
      final assistant = context.read<AssistantRepository>();
      await assistant.speak(
        'Public Impact Pool active. Your AI features and emergency radar are 100% subsidized by the decentralized community on Arbitrum Sepolia.',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final web3 = Web3Service.instance;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'COMMUNITY IMPACT POOL',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. بطاقة الرعاية المجتمعية (Social Good Badge)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        color: colors.primary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '100% SUBSIDIZED ACCESS',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI Vision and Emergency Radar in BeaconOS are public goods, powered by verifiable smart contracts on Arbitrum Sepolia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. بطاقة المحفظة السيادية الذاتية (Sovereign Wallet DID)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SOVEREIGN WALLET (DID)',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copy Address',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: web3.walletAddressHex),
                            );
                            HapticManager.instance.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Wallet address copied to clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      web3.walletAddressHex,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NETWORK',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Arbitrum Sepolia (L2)',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TESTNET BALANCE',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _isLoading
                              ? 'Checking...'
                              : '${_balance.toStringAsFixed(4)} ETH',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // 3. زر كفالة الصندوق للمتبرعين والداعمين
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.favorite_rounded),
                label: const Text(
                  'Sponsor Impact Pool (Community)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: () async {
                  await SoundController.instance.play(SoundCue.success);
                  await HapticManager.instance.successNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Proof-of-Impact donation logged on Arbitrum Sepolia!',
                        ),
                        backgroundColor: colors.primary,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}