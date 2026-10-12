// lib/desktop/view/desktop_shell_page.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/view/desktop_topology_view.dart'; // 👈 استيراد الواجهة الجديدة
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
          // 1. الشريط الجانبي الدائم
          DesktopSidebar(
            selectedDestination: _currentDestination,
            onDestinationSelected: (dest) {
              setState(() => _currentDestination = dest);
            },
          ),

          // 2. مساحة العمل المركزية العريضة
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
        // 🚀 تم الاستبدال بستوديو الفضاء الحقيقي
        return const DesktopTopologyView(
          key: ValueKey('desktop_topology_view'),
        );
      case DesktopDestination.agenda:
        return const _PlaceholderView(
          key: ValueKey('desktop_agenda_view'),
          title: 'AGENDA & TASKS BOARD',
          subtitle:
              'Full-screen Zen Kanban, keyboard-driven task priorities and voice notes.',
          icon: Icons.calendar_today_rounded,
        );
      case DesktopDestination.focus:
        return const _PlaceholderView(
          key: ValueKey('focus_view'),
          title: 'FOCUS SESSIONS & ALARMS',
          subtitle:
              'Deep work history, Pomodoro analytics, and Android clock sync schedule.',
          icon: Icons.hourglass_top_rounded,
        );
      case DesktopDestination.comms:
        return const _PlaceholderView(
          key: ValueKey('comms_view'),
          title: 'SAFETY RADAR & COMMUNICATIONS',
          subtitle:
              'Directory, emergency contacts priority, and real-time GPS SOS logs.',
          icon: Icons.shield_rounded,
        );
      case DesktopDestination.settings:
        return const _PlaceholderView(
          key: ValueKey('settings_view'),
          title: 'VAULT & CLOUD SETTINGS',
          subtitle:
              'Bidirectional Supabase sync manager, backup status, and system persona.',
          icon: Icons.tune_rounded,
        );
    }
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: colors.primary, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}