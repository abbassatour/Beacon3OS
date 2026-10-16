// lib/tv/modes/pairing/tv_pairing_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TvPairingView extends StatelessWidget {
  const TvPairingView({
    required this.pairingCode,
    required this.refreshCodeFocus,
    required this.skipPairingFocus,
    required this.onRefreshCode,
    required this.onContinueStandalone,
    super.key,
  });

  final String? pairingCode;
  final FocusNode refreshCodeFocus;
  final FocusNode skipPairingFocus;
  final VoidCallback onRefreshCode;
  final VoidCallback onContinueStandalone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final code = pairingCode ?? '------';
    final part1 = code.length >= 3 ? code.substring(0, 3) : '---';
    final part2 = code.length >= 6 ? code.substring(3, 6) : '---';

    return Padding(
      key: const ValueKey('tv_pairing_screen'),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.wifi_tethering_rounded,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'BEACON OS • ZERO-LOGIN DEVICE LINK',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect Living Room TV',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No passwords or accounts required. Hold anywhere on your phone screen and speak the code aloud:',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCodeDigitsBox(context, part1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '—',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _buildCodeDigitsBox(context, part2),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_rounded,
                          color: colors.secondary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Voice Command: "Pair $part1 $part2"',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _buildRemoteActionButton(
                      focusNode: refreshCodeFocus,
                      icon: Icons.refresh_rounded,
                      label: 'Generate New Code',
                      onPressed: onRefreshCode,
                      colors: colors,
                    ),
                    const SizedBox(width: 16),
                    _buildRemoteActionButton(
                      focusNode: skipPairingFocus,
                      icon: Icons.skip_next_rounded,
                      label: 'Continue Standalone',
                      onPressed: onContinueStandalone,
                      colors: colors,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 4,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.5),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.12),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: context.scaffoldBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.outline),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 110,
                            color: colors.primary.withValues(alpha: 0.7),
                          ),
                          Positioned(
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SOVEREIGN DID',
                                style: TextStyle(
                                  color: colors.surface,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'P2P VAULT RELAY',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arbitrum Sepolia L2 Attestation\n& Local LAN Direct (< 2ms)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeDigitsBox(BuildContext context, String digits) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        digits,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildRemoteActionButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colors,
  }) {
    return FocusableActionDetector(
      focusNode: focusNode,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => onPressed(),
        ),
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isFocused ? colors.primary : colors.surface,
                foregroundColor: isFocused ? colors.surface : colors.onSurface,
                side: BorderSide(
                  color: isFocused ? colors.primary : colors.outline,
                  width: isFocused ? 2.2 : 1.2,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(icon, size: 18),
              label: Text(
                label,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              onPressed: onPressed,
            ),
          );
        },
      ),
    );
  }
}