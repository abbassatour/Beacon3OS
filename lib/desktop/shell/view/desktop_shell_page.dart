// lib/desktop/view/desktop_shell_page.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/agenda/view/desktop_agenda_view.dart';
import 'package:beacon_os/desktop/comms/view/desktop_comms_view.dart';
import 'package:beacon_os/desktop/focus/view/desktop_focus_view.dart';
import 'package:beacon_os/desktop/settings/view/desktop_settings_view.dart';
import 'package:beacon_os/desktop/topology/view/desktop_topology_view.dart';
import 'package:beacon_os/desktop/shell/widgets/desktop_sidebar.dart';
import 'package:flutter/material.dart';

class DesktopShellPage extends StatefulWidget {
  const DesktopShellPage({super.key});

  @override
  State<DesktopShellPage> createState() => _DesktopShellPageState();
}

class _DesktopShellPageState extends State<DesktopShellPage> {
  DesktopDestination _currentDestination = DesktopDestination.topology;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Row(
        children: [
          // 1. Ø§Ù„Ø´Ø±ÙŠØ· Ø§Ù„Ø¬Ø§Ù†Ø¨ÙŠ Ø§Ù„Ø¯Ø§Ø¦Ù… Ù„Ù„ØªÙ†Ù‚Ù„ Ø§Ù„Ø³Ø±ÙŠØ¹
          DesktopSidebar(
            selectedDestination: _currentDestination,
            onDestinationSelected: (dest) {
              setState(() => _currentDestination = dest);
            },
          ),

          // 2. Ù…Ø³Ø§Ø­Ø© Ø§Ù„Ø¹Ù…Ù„ Ø§Ù„Ù…Ø±ÙƒØ²ÙŠØ© Ø§Ù„Ø¹Ø±ÙŠØ¶Ø© Ù…Ø¹ Ø§Ù†ØªÙ‚Ø§Ù„ Ø³Ù„Ø³ Ø¨ÙŠÙ† Ø§Ù„Ø´Ø§Ø´Ø§Øª
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildActiveView(_currentDestination),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(DesktopDestination destination) {
    switch (destination) {
      case DesktopDestination.topology:
        // ðŸ§­ Ø³ØªÙˆØ¯ÙŠÙˆ Ø§Ù„ÙØ¶Ø§Ø¡ ÙˆØ§Ù„Ø´Ø¨ÙƒØ© Ø§Ù„Ø¯ÙŠÙƒØ§Ø±ØªÙŠØ© Ø§Ù„ØªÙØ§Ø¹Ù„ÙŠØ©
        return const DesktopTopologyView(
          key: ValueKey('desktop_topology_view'),
        );

      case DesktopDestination.agenda:
        // ðŸ“‹ Ù„ÙˆØ­Ø© Ø§Ù„Ø£Ø¬Ù†Ø¯Ø© ÙˆØ§Ù„ÙƒØ§Ù†Ø¨Ø§Ù† ÙˆØ¥Ø¯Ø®Ø§Ù„ Ø§Ù„Ù…Ù‡Ø§Ù… Ø§Ù„Ø³Ø±ÙŠØ¹
        return const DesktopAgendaView(
          key: ValueKey('desktop_agenda_view'),
        );

      case DesktopDestination.focus:
        // â³ Ù…Ø¤Ù‚Øª Ø§Ù„Ø¨ÙˆÙ…ÙˆØ¯ÙˆØ±Ùˆ ÙˆØ¬Ù„Ø³Ø§Øª Ø§Ù„Ø¹Ù…Ù„ ÙˆØ³Ø¬Ù„ Ø§Ù„Ù…Ù†Ø¨Ù‡Ø§Øª
        return const DesktopFocusView(
          key: ValueKey('desktop_focus_view'),
        );

      case DesktopDestination.comms:
        // ðŸ›¡ï¸ Ø±Ø§Ø¯Ø§Ø± Ø§Ù„Ø·ÙˆØ§Ø±Ø¦ SOS ÙˆØ¯Ù„ÙŠÙ„ Ø§Ù„Ù‡Ø§ØªÙ ÙˆØ±Ø³Ø§Ø¦Ù„ Ø§Ù„Ø®Ø²Ù†Ø©
        return const DesktopCommsView(
          key: ValueKey('desktop_comms_view'),
        );

      case DesktopDestination.settings:
        // âš™ï¸ Ù…ÙØªØ´ Ø§Ù„Ø³Ø­Ø§Ø¨Ø© ÙˆØ§Ù„Ù…Ø²Ø§Ù…Ù†Ø© Ø§Ù„ÙÙˆØ±ÙŠØ© ÙˆØªØ¨Ø¯ÙŠÙ„ Ø§Ù„Ø«ÙŠÙ… ÙˆØ§Ù„Ù‡ÙˆÙŠØ©
        return const DesktopSettingsView(
          key: ValueKey('desktop_settings_view'),
        );
    }
  }
}

