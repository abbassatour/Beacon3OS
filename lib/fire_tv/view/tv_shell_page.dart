// lib/fire_tv/view/tv_shell_page.dart
import 'dart:async';

import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class TvShellPage extends StatefulWidget {
  const TvShellPage({super.key});

  @override
  State<TvShellPage> createState() => _TvShellPageState();
}

class _TvShellPageState extends State<TvShellPage> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  StreamSubscription<RemoteActionEvent>? _remoteSub;
  RemoteActionEvent? _activeAlert;
  Timer? _alertDismissTimer;

  // إدارة التركيز بالريموت (D-Pad Focus Nodes)
  final FocusNode _sosCardFocus = FocusNode();
  final FocusNode _locateCardFocus = FocusNode();
  final FocusNode _agendaFocus = FocusNode();
  final FocusNode _alarmsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    final commsRepo = context.read<CommsRepository>();
    _remoteSub = commsRepo.remoteActionEvents.listen((event) {
      if (mounted) {
        setState(() => _activeAlert = event);
        _alertDismissTimer?.cancel();
        _alertDismissTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) setState(() => _activeAlert = null);
        });
      }
    });

    // تركيز أولي تلقائي للريموت
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateCardFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _alertDismissTimer?.cancel();
    _remoteSub?.cancel();
    _sosCardFocus.dispose();
    _locateCardFocus.dispose();
    _agendaFocus.dispose();
    _alarmsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('h:mm a').format(_currentTime);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_currentTime);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. شريط الحالة العلوي لشاشة التلفزيون
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary, width: 1.5),
                      ),
                      child: Icon(Icons.tv_rounded, color: colors.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BEACON OS • FIRE TV CANVAS',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          'Living Room Ambient Bridge & Family Radar',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.wifi_tethering_rounded, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'ALEXA+ MCP ONLINE',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          dateStr,
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
              ],
            ),
            const SizedBox(height: 20),

            // 2. راية التنبيه اللحظي عند استدعاء أليكسا أو إطلاق SOS
            if (_activeAlert != null) ...[
              _buildLiveAlertBanner(context, _activeAlert!),
              const SizedBox(height: 18),
            ],

            // 3. المحتوى الرئيسي المقسم لشبكة تلفزيونية عريضة قابلة للتنقل بالريموت
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // العمود الأيسر: الرادار التفاعلي وبحث الهاتف
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _TvCard(
                            focusNode: _locateCardFocus,
                            title: 'ACOUSTIC PHONE LOCATOR',
                            subtitle: 'Say "Alexa, find my Beacon phone" or press Select',
                            icon: Icons.radar_rounded,
                            accentColor: colors.primary,
                            onSelect: () {
                              context.read<CommsRepository>().executeLocateDevice();
                            },
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: colors.primary.withValues(alpha: 0.15),
                                    child: Icon(Icons.phonelink_ring_rounded, size: 48, color: colors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'PING PHONE HARDWARE',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'Triggers 100% siren, flashlight strobe & vibration',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 4,
                          child: _TvCard(
                            focusNode: _sosCardFocus,
                            title: 'FAMILY SAFETY RADAR (SOS)',
                            subtitle: 'Press Select to broadcast test rescue radar',
                            icon: Icons.emergency_rounded,
                            accentColor: colors.error,
                            onSelect: () {
                              context.read<CommsRepository>().triggerEmergencySos();
                            },
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 36, color: colors.error),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Triple-tap on Beacon Phone sends coordinates to this screen instantly.',
                                    style: TextStyle(color: colors.onSurface, fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // العمود الأيمن: الأجندة وقمرة القيادة المزامنة
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _TvCard(
                            focusNode: _agendaFocus,
                            title: 'AGENDA & PRIORITIES',
                            subtitle: 'Synced in real-time from mobile vault',
                            icon: Icons.calendar_today_rounded,
                            accentColor: colors.secondary,
                            child: _TvTasksList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 4,
                          child: _TvCard(
                            focusNode: _alarmsFocus,
                            title: 'UPCOMING ALARMS',
                            subtitle: 'Synchronized with Android Clock',
                            icon: Icons.alarm_rounded,
                            accentColor: colors.primary,
                            child: _TvAlarmsList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAlertBanner(BuildContext context, RemoteActionEvent alert) {
    final colors = context.colors;
    final isSos = alert.actionType == RemoteActionType.triggerSos;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isSos ? colors.error : colors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isSos ? colors.error : colors.primary).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isSos ? Icons.warning_rounded : Icons.cell_tower_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSos ? '🚨 EMERGENCY SOS ALERT ACTIVE' : '📍 ACOUSTIC PING DISPATCHED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  isSos
                      ? 'Live GPS broadcast received from user phone. Family radar alerted.'
                      : 'Living room query actuated phone siren and strobe flashlight.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
            ),
            onPressed: () => setState(() => _activeAlert = null),
            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _TvCard extends StatefulWidget {
  const _TvCard({
    required this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.onSelect,
  });

  final FocusNode focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final VoidCallback? onSelect;

  @override
  State<_TvCard> createState() => _TvCardState();
}

class _TvCardState extends State<_TvCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _isFocused = f),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) => widget.onSelect?.call(),
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isFocused ? widget.accentColor : colors.outline.withValues(alpha: 0.6),
            width: _isFocused ? 3.0 : 1.2,
          ),
          boxShadow: [
            if (_isFocused)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: widget.accentColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (_isFocused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PRESS [SELECT]',
                      style: TextStyle(color: colors.surface, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _TvTasksList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final taskRepo = context.read<TaskAgendaRepository>();

    return StreamBuilder<List<Task>>(
      stream: taskRepo.watchTasks(),
      builder: (context, snapshot) {
        final tasks = (snapshot.data ?? []).where((t) => !t.isCompleted).take(3).toList();

        if (tasks.isEmpty) {
          return Center(
            child: Text(
              'Zero pending priorities! Agenda is clear.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.scaffoldBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.radio_button_unchecked_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(color: colors.secondary, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TvAlarmsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final focusRepo = context.read<FocusAlarmsRepository>();

    return StreamBuilder<List<Alarm>>(
      stream: focusRepo.watchAlarms(),
      builder: (context, snapshot) {
        final alarms = (snapshot.data ?? []).where((a) => a.isActive).toList();

        if (alarms.isEmpty) {
          return Center(
            child: Text(
              'No active alarms scheduled.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          );
        }

        final next = alarms.first;
        final hour12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
        final period = next.hour >= 12 ? 'PM' : 'AM';
        final minStr = next.minute.toString().padLeft(2, '0');

        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$hour12:$minStr $period',
                style: TextStyle(color: colors.onSurface, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  next.label,
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}