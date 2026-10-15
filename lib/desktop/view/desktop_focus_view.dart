// lib/desktop/view/desktop_focus_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_focus_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_focus_state.dart';
import 'package:beacon_os/desktop/widgets/focus/alarms_scheduler_section.dart';
import 'package:beacon_os/desktop/widgets/focus/deep_work_section.dart';
import 'package:beacon_os/desktop/widgets/focus/focus_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopFocusView extends StatelessWidget {
  const DesktopFocusView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopFocusCubit(
        focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
      ),
      child: const _DesktopFocusContent(),
    );
  }
}

class _DesktopFocusContent extends StatelessWidget {
  const _DesktopFocusContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopFocusCubit, DesktopFocusState>(
      builder: (context, state) {
        if (state.status == DesktopFocusStatus.loading && state.alarms.isEmpty) {
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
                // 1. رأس الصفحة: العناوين والمقاييس السريعة
                FocusHeader(state: state),
                const SizedBox(height: 20),

                // 2. المحتوى المقسوم: المؤقت يساراً + المنبهات يميناً
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // القسم الأيسر: محرك البومودورو والعمل العميق
                      Expanded(
                        flex: 5,
                        child: DeepWorkSection(state: state),
                      ),
                      const SizedBox(width: 20),

                      // القسم الأيمن: جدول ومزامنة المنبهات
                      Expanded(
                        flex: 5,
                        child: AlarmsSchedulerSection(state: state),
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