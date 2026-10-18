// lib/desktop/settings/widgets/settings_header.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({required this.state, super.key});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return Row(
      children: [
        // 🌟 حماية العنوان والوصف من الطفح
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: colors.primary, size: 26),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'VAULT & SOVEREIGN SETTINGS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Arbitrum Sepolia DID ledger, peer-to-peer state relay, and Floor 1 engine controls.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: state.isSyncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.surface,
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 18),
          label: Text(
            state.isSyncing ? 'Syncing...' : 'Force Sync All',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          onPressed: state.isSyncing ? null : cubit.forceFullSync,
        ),
      ],
    );
  }
}