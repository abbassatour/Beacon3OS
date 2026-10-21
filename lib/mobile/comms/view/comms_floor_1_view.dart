// lib/mobile/comms/view/comms_floor_1_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/comms/cubit/comms_cubit.dart';
import 'package:beacon_os/mobile/comms/cubit/comms_state.dart';
import 'package:beacon_os/mobile/preferences/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// واجهة الطابق الأول لغرفة التواصل (Floor 1: Safety & SOS Radar Preferences)
class CommsFloor1View extends StatefulWidget {
  const CommsFloor1View({super.key});

  @override
  State<CommsFloor1View> createState() => _CommsFloor1ViewState();
}

class _CommsFloor1ViewState extends State<CommsFloor1View> {
  final TextEditingController _codeInputController = TextEditingController();

  @override
  void dispose() {
    _codeInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<PreferencesCubit, PreferencesState>(
          builder: (context, prefState) {
            final prefCubit = context.read<PreferencesCubit>();

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
                            Icon(Icons.shield_rounded, color: colors.error, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'SAFETY & SOS RADAR',
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
                          'Floor 1 • Emergency auto-dialing, live GPS broadcasting & SMS alerts.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 🔗 بطاقة الاقتران التفاعلية تستخدم CommsCubit العام المرفوع بالأعلى
                      BlocBuilder<CommsCubit, CommsState>(
                        builder: (context, commsState) {
                          final commsCubit = context.read<CommsCubit>();
                          return _buildPairingCard(context, commsState, commsCubit);
                        },
                      ),
                      const SizedBox(height: 12),

                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Auto-Dial Emergency Primary Contact',
                            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Instantly initiate direct phone call upon SOS broadcast.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                          activeColor: colors.error,
                          value: prefState.autoDialEmergency,
                          onChanged: prefCubit.toggleAutoDialEmergency,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Share Live GPS on SOS',
                            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Generate Google Maps live coordinates link for rescue team.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                          activeColor: colors.error,
                          value: prefState.shareGpsOnSos,
                          onChanged: prefCubit.toggleShareGpsOnSos,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCard(
                        context,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Speak Incoming Messages Aloud',
                            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Read sender name and message content via high-clarity TTS.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                          activeColor: colors.primary,
                          value: prefState.speakIncomingSms,
                          onChanged: prefCubit.toggleSpeakIncomingSms,
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

  Widget _buildPairingCard(BuildContext context, CommsState state, CommsCubit cubit) {
    final colors = context.colors;

    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tv_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'LIVING ROOM SCREEN PAIRING',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.isDeviceLinked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LINKED TO DISPLAY',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          state.linkedVaultId ?? 'Remote Display',
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
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: const Text('Unpair', style: TextStyle(fontSize: 12)),
                    onPressed: cubit.unpairDevice,
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Enter the 6-digit code shown on your Fire TV or Desktop to link your sovereign vault locally.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeInputController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      letterSpacing: 3,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 849201',
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
                  onPressed: state.status == CommsStatus.loading
                      ? null
                      : () {
                          final code = _codeInputController.text.trim();
                          if (code.length == 6) {
                            cubit.authorizePairingCode(code);
                            _codeInputController.clear();
                          }
                        },
                  child: const Text(
                    'Link',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
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