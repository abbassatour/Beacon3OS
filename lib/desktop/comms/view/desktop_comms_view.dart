// lib/desktop/comms/view/desktop_comms_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/comms/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/comms/cubit/desktop_comms_state.dart';
import 'package:beacon_os/desktop/comms/widgets/comms_header.dart';
import 'package:beacon_os/desktop/comms/widgets/directory_panel.dart';
import 'package:beacon_os/desktop/comms/widgets/emergency_radar_panel.dart';
import 'package:beacon_os/desktop/comms/widgets/unread_messages_panel.dart';
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
        safetyRadarRepository: context.read<SafetyRadarRepository>(),
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
                // 1. رأس الصفحة
                CommsHeader(state: state),
                const SizedBox(height: 20),

                // 2. شبكة الألواح المتجاوبة التي تمنع طفح القاع والعرض
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // إذا كان العرض ضيقاً (< 880px)، نوزع الألواح على عمودين لتفادي التزاحم
                      if (constraints.maxWidth < 880) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: EmergencyRadarPanel(state: state),
                                  ),
                                  const SizedBox(height: 14),
                                  Expanded(
                                    flex: 4,
                                    child: UnreadMessagesPanel(state: state),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: DirectoryPanel(state: state),
                            ),
                          ],
                        );
                      }

                      // التوزيع الثلاثي القياسي للشاشات الواسعة
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: EmergencyRadarPanel(state: state),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: DirectoryPanel(state: state),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: UnreadMessagesPanel(state: state),
                          ),
                        ],
                      );
                    },
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