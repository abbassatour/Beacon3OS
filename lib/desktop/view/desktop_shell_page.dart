// lib/desktop/view/desktop_shell_page.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/view/desktop_agenda_view.dart';
import 'package:beacon_os/desktop/view/desktop_comms_view.dart';
import 'package:beacon_os/desktop/view/desktop_focus_view.dart';
import 'package:beacon_os/desktop/view/desktop_settings_view.dart';
import 'package:beacon_os/desktop/view/desktop_topology_view.dart';
import 'package:beacon_os/desktop/widgets/desktop_sidebar.dart';
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
          // 1. الشريط الجانبي الدائم للتنقل السريع
          DesktopSidebar(
            selectedDestination: _currentDestination,
            onDestinationSelected: (dest) {
              setState(() => _currentDestination = dest);
            },
          ),

          // 2. مساحة العمل المركزية العريضة مع انتقال سلس بين الشاشات
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
        // 🧭 ستوديو الفضاء والشبكة الديكارتية التفاعلية
        return const DesktopTopologyView(
          key: ValueKey('desktop_topology_view'),
        );

      case DesktopDestination.agenda:
        // 📋 لوحة الأجندة والكانبان وإدخال المهام السريع
        return const DesktopAgendaView(
          key: ValueKey('desktop_agenda_view'),
        );

      case DesktopDestination.focus:
        // ⏳ مؤقت البومودورو وجلسات العمل وسجل المنبهات
        return const DesktopFocusView(
          key: ValueKey('desktop_focus_view'),
        );

      case DesktopDestination.comms:
        // 🛡️ رادار الطوارئ SOS ودليل الهاتف ورسائل الخزنة
        return const DesktopCommsView(
          key: ValueKey('desktop_comms_view'),
        );

      case DesktopDestination.settings:
        // ⚙️ مفتش السحابة والمزامنة الفورية وتبديل الثيم والهوية
        return const DesktopSettingsView(
          key: ValueKey('desktop_settings_view'),
        );
    }
  }
}