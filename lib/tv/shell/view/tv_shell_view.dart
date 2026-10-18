// lib/tv/shell/view/tv_shell_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/modes/ambient/tv_ambient_screensaver.dart';
import 'package:beacon_os/tv/modes/dashboard/tv_dashboard_view.dart';
import 'package:beacon_os/tv/modes/pairing/tv_pairing_view.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_cubit.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TvShellView extends StatefulWidget {
  const TvShellView({super.key});

  @override
  State<TvShellView> createState() => _TvShellViewState();
}

class _TvShellViewState extends State<TvShellView> {
  final FocusNode _locateCardFocus = FocusNode();
  final FocusNode _sosCardFocus = FocusNode();
  final FocusNode _agendaFocus = FocusNode();
  final FocusNode _alarmsFocus = FocusNode();
  final FocusNode _refreshCodeFocus = FocusNode();
  final FocusNode _skipPairingFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 🌟 تفعيل الفوكس للبطاقة الأولى فور تحميل الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleFocusTransitions(context.read<TvShellCubit>().state);
    });
  }

  @override
  void dispose() {
    _locateCardFocus.dispose();
    _sosCardFocus.dispose();
    _agendaFocus.dispose();
    _alarmsFocus.dispose();
    _refreshCodeFocus.dispose();
    _skipPairingFocus.dispose();
    super.dispose();
  }

  void _handleFocusTransitions(TvShellState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (state.isDashboard) {
        // إذا لم تكن أي من البطاقات محددة بالفعل، يتم توجيه الفوكس للبطاقة الأولى
        final bool anyCardHasFocus = _locateCardFocus.hasFocus ||
            _sosCardFocus.hasFocus ||
            _agendaFocus.hasFocus ||
            _alarmsFocus.hasFocus;

        if (!anyCardHasFocus) {
          _locateCardFocus.requestFocus();
        }
      } else if (state.isPairing &&
          !_refreshCodeFocus.hasFocus &&
          !_skipPairingFocus.hasFocus) {
        _refreshCodeFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TvShellCubit>();

    return BlocConsumer<TvShellCubit, TvShellState>(
      listenWhen: (prev, curr) => prev.mode != curr.mode,
      listener: (context, state) => _handleFocusTransitions(state),
      builder: (context, state) {
        return PopScope(
          canPop: false, // حماية الجلسة من الإغلاق غير المقصود
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (state.hasActiveAlert) {
              cubit.dismissActiveAlert();
            } else if (state.isDashboard) {
              cubit.wakeFromAmbient();
            }
          },
          child: Focus(
            // 🚨 كان autofocus: true يحتكر الفوكس ويمنع وصول الأسهم للبطاقات
            canRequestFocus: false, // 👈 يمنع احتكار الفوكس ويسمح للبطاقات بالتحكم
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                cubit.wakeFromAmbient();
              }
              return KeyEventResult.ignored; // السماح بمرور الأحداث للأزرار والبطاقات
            },
            child: Scaffold(
              backgroundColor: context.scaffoldBg,
              body: SafeArea(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: _resolveActiveScreen(context, state, cubit),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resolveActiveScreen(
    BuildContext context,
    TvShellState state,
    TvShellCubit cubit,
  ) {
    if (state.isCheckingLink) {
      return const Center(
        key: ValueKey('tv_checking_link'),
        child: CircularProgressIndicator(),
      );
    }

    if (state.isAmbient) {
      return TvAmbientScreensaver(currentTime: state.currentTime);
    }

    if (state.isPairing) {
      return TvPairingView(
        pairingCode: state.activePairingCode,
        refreshCodeFocus: _refreshCodeFocus,
        skipPairingFocus: _skipPairingFocus,
        onRefreshCode: cubit.startNewPairingSession,
        onContinueStandalone: cubit.continueStandalone,
      );
    }

    return TvDashboardView(
      locateCardFocus: _locateCardFocus,
      sosCardFocus: _sosCardFocus,
      agendaFocus: _agendaFocus,
      alarmsFocus: _alarmsFocus,
    );
  }
}