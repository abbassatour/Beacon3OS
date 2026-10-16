// lib/desktop/widgets/desktop_sidebar.dart
import 'package:beacon_os/core/services/web3_service.dart'; // ðŸ‘ˆ Ø§Ø³ØªÙŠØ±Ø§Ø¯ Ø®Ø¯Ù…Ø© Ø§Ù„Ø¨Ù„ÙˆÙƒØ´ÙŠÙ†
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum DesktopDestination {
  topology(
    title: 'Spatial Topology',
    subtitle: 'Room Layout Studio',
    icon: Icons.grid_view_rounded,
  ),
  agenda(
    title: 'Agenda & Tasks',
    subtitle: 'Priorities Board',
    icon: Icons.calendar_today_rounded,
  ),
  focus(
    title: 'Focus & Timer',
    subtitle: 'Deep Work Analytics',
    icon: Icons.hourglass_top_rounded,
  ),
  comms(
    title: 'Safety & Radar',
    subtitle: 'Contacts & SOS Log',
    icon: Icons.shield_rounded,
  ),
  settings(
    title: 'Sovereign & Vault',
    subtitle: 'DID & Preferences',
    icon: Icons.tune_rounded,
  );

  const DesktopDestination({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class DesktopSidebar extends StatefulWidget {
  const DesktopSidebar({
    required this.selectedDestination,
    required this.onDestinationSelected,
    super.key,
  });

  final DesktopDestination selectedDestination;
  final ValueChanged<DesktopDestination> onDestinationSelected;

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOled = Theme.of(context).brightness == Brightness.dark;

    final width = _isCollapsed ? 76.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(
            color: colors.outline.withValues(alpha: 0.7),
            width: 1.2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ø±Ø£Ø³ Ø§Ù„Ø´Ø±ÙŠØ· Ø§Ù„Ø¬Ø§Ù†Ø¨ÙŠ (Header)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 18,
              vertical: 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isCollapsed)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.blur_on_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BEACON OS',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Text(
                            'Command Center',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                IconButton(
                  icon: Icon(
                    _isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  tooltip: _isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  onPressed: () =>
                      setState(() => _isCollapsed = !_isCollapsed),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Ø¹Ù†Ø§ØµØ± Ø§Ù„ØªÙ†Ù‚Ù„ (Navigation Items)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: DesktopDestination.values.map((destination) {
                final isSelected = widget.selectedDestination == destination;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onDestinationSelected(destination),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: colors.primary.withValues(alpha: 0.35),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              destination.icon,
                              color: isSelected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              size: 20,
                            ),
                            if (!_isCollapsed) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination.title,
                                      style: TextStyle(
                                        color: isSelected
                                            ? colors.primary
                                            : colors.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      destination.subtitle,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Ø´Ø±ÙŠØ· Ø§Ù„Ø­Ø§Ù„Ø© Ø§Ù„Ø³ÙÙ„ÙŠ (Web3 DID & Arbitrum Status Footer)
          _buildStatusFooter(context, isOled, colors),
        ],
      ),
    );
  }

  Widget _buildStatusFooter(
    BuildContext context,
    bool isOled,
    ColorScheme colors,
  ) {
    final web3 = Web3Service.instance;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 8 : 16,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: _isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          if (!_isCollapsed)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arbitrum L2: Connected',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      web3.shortAddress,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          IconButton(
            icon: Icon(
              isOled ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: colors.primary,
              size: 20,
            ),
            tooltip: isOled ? 'Warm Paper Theme' : 'High Contrast OLED',
            onPressed: () {
              context.read<ThemeCubit>().toggleTheme(isHighContrast: !isOled);
            },
          ),
        ],
      ),
    );
  }
}
