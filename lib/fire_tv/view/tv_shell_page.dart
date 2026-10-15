// lib/fire_tv/view/tv_shell_page.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
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

class _TvShellPageState extends State<TvShellPage> with TickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  StreamSubscription<RemoteActionEvent>? _remoteSub;
  RemoteActionEvent? _activeAlert;
  Timer? _alertDismissTimer;

  // وضع الخمول لحماية شاشات OLED من الاحتراق
  Timer? _screensaverTimer;
  bool _isAmbientMode = false;

  final FocusNode _locateCardFocus = FocusNode();
  final FocusNode _sosCardFocus = FocusNode();
  final FocusNode _agendaFocus = FocusNode();
  final FocusNode _alarmsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _resetScreensaverTimer();

    final commsRepo = context.read<CommsRepository>();
    _remoteSub = commsRepo.remoteActionEvents.listen((event) {
      if (!mounted) return;

      _wakeFromAmbient();
      setState(() => _activeAlert = event);

      if (event.actionType == RemoteActionType.triggerSos) {
        SoundController.instance.play(SoundCue.sosAlarm);
      } else if (event.actionType == RemoteActionType.locateDevice) {
        SoundController.instance.play(SoundCue.wake);
      }

      _alertDismissTimer?.cancel();
      _alertDismissTimer = Timer(const Duration(seconds: 20), () {
        if (mounted) {
          setState(() => _activeAlert = null);
          SoundController.instance.stopAll();
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locateCardFocus.requestFocus();
    });
  }

  void _resetScreensaverTimer() {
    _screensaverTimer?.cancel();
    _screensaverTimer = Timer(const Duration(seconds: 75), () {
      if (mounted && _activeAlert == null) {
        setState(() => _isAmbientMode = true);
      }
    });
  }

  void _wakeFromAmbient() {
    _resetScreensaverTimer();
    if (_isAmbientMode) {
      setState(() => _isAmbientMode = false);
      _locateCardFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _screensaverTimer?.cancel();
    _alertDismissTimer?.cancel();
    _remoteSub?.cancel();
    _locateCardFocus.dispose();
    _sosCardFocus.dispose();
    _agendaFocus.dispose();
    _alarmsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _wakeFromAmbient();
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _isAmbientMode
                ? _buildAmbientScreensaver(context)
                : _buildMainDashboard(context),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 📺 1. لوحة التحكم المتجاوبة تماماً مع شاشة التلفزيون
  // ===========================================================================
  Widget _buildMainDashboard(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('h:mm a').format(_currentTime);
    final dateStr = DateFormat('EEE, MMM d').format(_currentTime);

    return Padding(
      key: const ValueKey('tv_active_dashboard'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط الحالة العلوي المستجيب (Responsive Header Bar)
          Row(
            children: [
              // الطرف الأيسر: الشعار واسم النظام
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary, width: 1.5),
                      ),
                      child: Icon(Icons.tv_rounded, color: colors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BEACON OS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Living Room Bridge',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // الطرف الأيمن: الشارات والساعة
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPillBadge(
                    icon: Icons.wifi_tethering_rounded,
                    label: 'ALEXA+',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildPillBadge(
                    icon: Icons.verified_rounded,
                    label: 'ARBITRUM',
                    color: colors.primary,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        dateStr,
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
            ],
          ),
          const SizedBox(height: 12),

          if (_activeAlert != null) ...[
            _buildLiveAlertBanner(context, _activeAlert!),
            const SizedBox(height: 12),
          ],

          // شبكة البطاقات التفاعلية (2x2 Matrix)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // العمود الأيسر: الرادار واستدعاء الهاتف
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _TvCardResponsive(
                          focusNode: _locateCardFocus,
                          title: 'ACOUSTIC PHONE LOCATOR',
                          subtitle: 'Press [SELECT] to ping missing phone',
                          icon: Icons.radar_rounded,
                          accentColor: colors.primary,
                          onSelect: () {
                            context.read<CommsRepository>().executeLocateDevice();
                            SoundController.instance.play(SoundCue.wake);
                          },
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TvPulsingRadarIcon(
                                    icon: Icons.phonelink_ring_rounded,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'PING PHONE HARDWARE',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Triggers 100% siren, flashlight & haptics',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 4,
                        child: _TvCardResponsive(
                          focusNode: _sosCardFocus,
                          title: 'FAMILY SAFETY RADAR (SOS)',
                          subtitle: 'Simulate on-chain emergency alert',
                          icon: Icons.emergency_rounded,
                          accentColor: colors.error,
                          onSelect: () {
                            context.read<CommsRepository>().triggerEmergencySos();
                            SoundController.instance.play(SoundCue.sosAlarm);
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: colors.error.withValues(alpha: 0.15),
                                child: Icon(Icons.warning_amber_rounded, size: 26, color: colors.error),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Triple-tapping Beacon phone broadcasts real-time GPS coordinates here and anchors an attestation on Arbitrum Sepolia.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // العمود الأيمن: الأولويات الحية والمنبهات
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _TvCardResponsive(
                          focusNode: _agendaFocus,
                          title: 'AGENDA & PRIORITIES',
                          subtitle: 'Press [SELECT] to toggle tasks',
                          icon: Icons.calendar_today_rounded,
                          accentColor: colors.secondary,
                          child: const _TvInteractiveTasksList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 4,
                        child: _TvCardResponsive(
                          focusNode: _alarmsFocus,
                          title: 'UPCOMING ALARMS',
                          subtitle: 'Synchronized with Android Clock',
                          icon: Icons.alarm_rounded,
                          accentColor: colors.primary,
                          child: const _TvInteractiveAlarmsList(),
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
    );
  }

  // ===========================================================================
  // 🌙 2. وضع شاشة الخمول المهدئ (OLED Zen Screensaver)
  // ===========================================================================
  Widget _buildAmbientScreensaver(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('h:mm').format(_currentTime);
    final periodStr = DateFormat('a').format(_currentTime);
    final dateStr = DateFormat('EEEE, MMMM d').format(_currentTime);

    return Center(
      key: const ValueKey('tv_ambient_screensaver'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 90,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                periodStr,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radio_button_checked_rounded, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Living Room Bridge Active • Press any remote button to wake',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAlertBanner(BuildContext context, RemoteActionEvent alert) {
    final colors = context.colors;
    final isSos = alert.actionType == RemoteActionType.triggerSos;
    final bannerColor = isSos ? colors.error : colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isSos ? Icons.warning_rounded : Icons.cell_tower_rounded,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSos
                      ? '🚨 EMERGENCY SOS ACTIVE • ON-CHAIN ATTESTED'
                      : '📍 ACOUSTIC PING DISPATCHED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  isSos
                      ? 'Distress radar broadcasting live coordinates to Arbitrum ledger.'
                      : 'Living room voice query triggered hardware siren & flashlight strobe.',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() => _activeAlert = null);
              SoundController.instance.stopAll();
            },
            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 🎛️ بطاقة التلفزيون المتجاوبة مع حركة الريموت (TvCard with D-Pad Animation)
// =============================================================================
class _TvCardResponsive extends StatefulWidget {
  const _TvCardResponsive({
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
  State<_TvCardResponsive> createState() => _TvCardResponsiveState();
}

class _TvCardResponsiveState extends State<_TvCardResponsive> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onSelect?.call(),
        ),
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isFocused ? widget.accentColor : colors.outline.withValues(alpha: 0.5),
              width: _isFocused ? 3.0 : 1.2,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: widget.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (_isFocused)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PRESS [SELECT]',
                        style: TextStyle(color: colors.surface, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const Divider(height: 16, thickness: 1.0),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 💫 أيقونة الرادار النبضي التفاعلي (Pulsing Radar Visualizer)
// =============================================================================
class _TvPulsingRadarIcon extends StatefulWidget {
  const _TvPulsingRadarIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_TvPulsingRadarIcon> createState() => _TvPulsingRadarIconState();
}

class _TvPulsingRadarIconState extends State<_TvPulsingRadarIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 70 + (_controller.value * 24),
              height: 70 + (_controller.value * 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: (1.0 - _controller.value) * 0.5),
                  width: 1.8,
                ),
              ),
            ),
            CircleAvatar(
              radius: 34,
              backgroundColor: widget.color.withValues(alpha: 0.15),
              child: Icon(widget.icon, size: 34, color: widget.color),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// 📋 قائمة المهام التفاعلية لشاشات التلفزيون (Interactive TV Tasks)
// =============================================================================
class _TvInteractiveTasksList extends StatelessWidget {
  const _TvInteractiveTasksList();

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
              'Zero pending priorities! Agenda clear.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return InkWell(
              onTap: () {
                taskRepo.toggleTask(task);
                SoundController.instance.play(SoundCue.success);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.scaffoldBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked_rounded, size: 16, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.priority.toUpperCase(),
                        style: TextStyle(color: colors.secondary, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// ⏰ قائمة المنبهات التفاعلية لشاشات التلفزيون (Interactive TV Alarms)
// =============================================================================
class _TvInteractiveAlarmsList extends StatelessWidget {
  const _TvInteractiveAlarmsList();

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
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }

        final next = alarms.first;
        final hour12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
        final period = next.hour >= 12 ? 'PM' : 'AM';
        final minStr = next.minute.toString().padLeft(2, '0');

        return InkWell(
          onTap: () {
            focusRepo.toggleAlarm(next);
            SoundController.instance.play(SoundCue.navCenter);
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$hour12:$minStr $period',
                  style: TextStyle(color: colors.onSurface, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.primary, width: 1.2),
                  ),
                  child: Text(
                    next.label,
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 12),
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