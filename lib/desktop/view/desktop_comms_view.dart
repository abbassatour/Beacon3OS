// lib/desktop/view/desktop_comms_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_state.dart';
import 'package:beacon_os/desktop/widgets/comms/comms_header.dart';
import 'package:beacon_os/desktop/widgets/comms/directory_panel.dart';
import 'package:beacon_os/desktop/widgets/comms/emergency_radar_panel.dart';
import 'package:beacon_os/desktop/widgets/comms/unread_messages_panel.dart';
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
                // 1. رأس الصفحة: العناوين وأزرار العمليات
                CommsHeader(state: state),
                const SizedBox(height: 20),

                // 2. المحتوى المقسوم على 3 لوحات
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // اللوحة 1: جهات اتصال الطوارئ والرادار اللامركزي
                      Expanded(
                        flex: 5,
                        child: EmergencyRadarPanel(state: state),
                      ),
                      const SizedBox(width: 18),

                      // اللوحة 2: دليل جهات الاتصال الشامل
                      Expanded(
                        flex: 4,
                        child: DirectoryPanel(state: state),
                      ),
                      const SizedBox(width: 18),

                      // اللوحة 3: رسائل الخزنة الواردة
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