// lib/tv/shell/view/tv_shell_page.dart
import 'package:beacon_os/tv/cards/agenda/cubit/tv_agenda_cubit.dart';
import 'package:beacon_os/tv/cards/alarms/cubit/tv_alarms_cubit.dart';
import 'package:beacon_os/tv/cards/locator/cubit/tv_locator_cubit.dart';
import 'package:beacon_os/tv/cards/safety/cubit/tv_safety_cubit.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_cubit.dart';
import 'package:beacon_os/tv/shell/view/tv_shell_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvShellPage extends StatelessWidget {
  const TvShellPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const TvShellPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TvShellCubit>(
          create: (context) => TvShellCubit(
            commsRepository: context.read<CommsRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
            ringRepository: context.read<LauncherRepository>().ring, // 👈 تم توفير ringRepository
          ),
        ),
        BlocProvider<TvAgendaCubit>(
          create: (context) => TvAgendaCubit(
            taskRepository: context.read<TaskAgendaRepository>(),
          ),
        ),
        BlocProvider<TvAlarmsCubit>(
          create: (context) => TvAlarmsCubit(
            focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
          ),
        ),
        BlocProvider<TvLocatorCubit>(
          create: (context) => TvLocatorCubit(
            commsRepository: context.read<CommsRepository>(),
          ),
        ),
        BlocProvider<TvSafetyCubit>(
          create: (context) => TvSafetyCubit(
            commsRepository: context.read<CommsRepository>(),
          ),
        ),
      ],
      child: const TvShellView(),
    );
  }
}