// lib/desktop/view/desktop_comms_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/comms/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/comms/cubit/desktop_comms_state.dart';
import 'package:beacon_os/desktop/comms/widgets/comms_header.dart';
import 'package:beacon_os/desktop/comms/widgets/directory_panel.dart';
import 'package:beacon_os/desktop/comms/widgets/emergency_radar_panel.dart';
import 'package:beacon_os/desktop/comms/widgets/unread_messages_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopCommsView extends StatelessWidget {
  const DesktopCommsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopCommsCubit(
        commsRepository: context.read<CommsRepository>(),
      ),
      child: const _DesktopCommsContent(),
    );
  }
}

class _DesktopCommsContent extends StatelessWidget {
  const _DesktopCommsContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopCommsCubit, DesktopCommsState>(
      builder: (context, state) {
        if (state.status == DesktopCommsStatus.loading && state.contacts.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Ø±Ø£Ø³ Ø§Ù„ØµÙØ­Ø©: Ø§Ù„Ø¹Ù†Ø§ÙˆÙŠÙ† ÙˆØ£Ø²Ø±Ø§Ø± Ø§Ù„Ø¹Ù…Ù„ÙŠØ§Øª
                CommsHeader(state: state),
                const SizedBox(height: 20),

                // 2. Ø§Ù„Ù…Ø­ØªÙˆÙ‰ Ø§Ù„Ù…Ù‚Ø³ÙˆÙ… Ø¹Ù„Ù‰ 3 Ù„ÙˆØ­Ø§Øª
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ø§Ù„Ù„ÙˆØ­Ø© 1: Ø¬Ù‡Ø§Øª Ø§ØªØµØ§Ù„ Ø§Ù„Ø·ÙˆØ§Ø±Ø¦ ÙˆØ§Ù„Ø±Ø§Ø¯Ø§Ø± Ø§Ù„Ù„Ø§Ù…Ø±ÙƒØ²ÙŠ
                      Expanded(
                        flex: 5,
                        child: EmergencyRadarPanel(state: state),
                      ),
                      const SizedBox(width: 18),

                      // Ø§Ù„Ù„ÙˆØ­Ø© 2: Ø¯Ù„ÙŠÙ„ Ø¬Ù‡Ø§Øª Ø§Ù„Ø§ØªØµØ§Ù„ Ø§Ù„Ø´Ø§Ù…Ù„
                      Expanded(
                        flex: 4,
                        child: DirectoryPanel(state: state),
                      ),
                      const SizedBox(width: 18),

                      // Ø§Ù„Ù„ÙˆØ­Ø© 3: Ø±Ø³Ø§Ø¦Ù„ Ø§Ù„Ø®Ø²Ù†Ø© Ø§Ù„ÙˆØ§Ø±Ø¯Ø©
                      Expanded(
                        flex: 3,
                        child: UnreadMessagesPanel(state: state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
