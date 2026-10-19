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
    // 🌟 التقاط أي زر من أزرار الريموت لإيقاظ الشاشة من وضع الخمول فوراً
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleFocusTransitions(context.read<TvShellCubit>().state);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _locateCardFocus.dispose();
    _sosCardFocus.dispose();
    _agendaFocus.dispose();
    _alarmsFocus.dispose();
    _refreshCodeFocus.dispose();
    _skipPairingFocus.dispose();
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final cubit = context.read<TvShellCubit>();
      if (cubit.state.isAmbient) {
        cubit.wakeFromAmbient();
        return true; // استهلاك الضغطة الأولى للاستيقاظ فقط
      } else {
        cubit.wakeFromAmbient(); // إعادة تصفير عداد الخمول
      }
    }
    return false; // تمرير الضغطة للبطاقة أو الزر المحدد
  }

  void _handleFocusTransitions(TvShellState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (state.isDashboard) {
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
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (state.hasActiveAlert) {
              cubit.dismissActiveAlert();
            } else if (state.isAmbient) {
              cubit.wakeFromAmbient(); // 👈 تصحيح الإيقاظ عند الضغط على Back
            }
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