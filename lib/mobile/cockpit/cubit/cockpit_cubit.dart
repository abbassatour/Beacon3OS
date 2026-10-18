// lib/mobile/cockpit/cubit/cockpit_cubit.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/mobile/cockpit/cubit/cockpit_state.dart';
import 'package:bloc/bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

class CockpitCubit extends Cubit<CockpitState> {
  CockpitCubit({
    required TaskAgendaRepository taskRepository,
    required FocusAlarmsRepository focusAlarmsRepository,
    required SystemHardwareRepository hardwareRepository,
    required AssistantRepository assistantRepository,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _tasksRepo = taskRepository,
        _focusRepo = focusAlarmsRepository,
        _hardwareRepo = hardwareRepository,
        _assistantRepo = assistantRepository,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const CockpitState()) {
    _initSubscriptions();
  }

  final TaskAgendaRepository _tasksRepo;
  final FocusAlarmsRepository _focusRepo;
  final SystemHardwareRepository _hardwareRepo;
  final AssistantRepository _assistantRepo;
  final HapticManager _haptics;
  final SoundController _sound;

  StreamSubscription<List<AlarmEntity>>? _alarmsSub;
  StreamSubscription<List<TaskEntity>>? _tasksSub;
  StreamSubscription<List<VoiceMemoEntity>>? _memosSub;
  Timer? _batteryTimer;

  void _initSubscriptions() {
    emit(state.copyWith(status: CockpitStatus.loading));

    _alarmsSub = _focusRepo.watchAlarms().listen((alarms) {
      if (isClosed) return;
      emit(state.copyWith(alarms: alarms, status: CockpitStatus.success));
    });

    _tasksSub = _tasksRepo.watchTasks().listen((tasks) {
      if (isClosed) return;
      emit(state.copyWith(tasks: tasks, status: CockpitStatus.success));
    });

    _memosSub = _tasksRepo.watchMemos().listen((memos) {
      if (isClosed) return;
      emit(state.copyWith(memos: memos, status: CockpitStatus.success));
    });

    refreshBattery();

    _batteryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!isClosed) {
        refreshBattery();
      }
    });
  }

  Future<void> refreshBattery() async {
    if (isClosed) return;
    final status = await _hardwareRepo.getBatteryStatus();
    if (isClosed) return;
    emit(state.copyWith(batteryStatus: status));
  }

  Future<void> playDailyBriefing() async {
    if (state.isBriefingPlaying) {
      await _assistantRepo.stopSpeaking();
      await _sound.stopAll();
      if (!isClosed) {
        emit(state.copyWith(isBriefingPlaying: false));
      }
      return;
    }

    await _sound.stopAll();
    await _assistantRepo.stopSpeaking();
    await _haptics.successNotification();
    await _sound.play(SoundCue.wake);

    if (isClosed) return;
    emit(state.copyWith(isBriefingPlaying: true));

    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    final buffer = StringBuffer('Good day. Today is $dateStr, $timeStr. ');

    if (state.nextAlarm != null) {
      final a = state.nextAlarm!;
      final hour12 = a.hour % 12 == 0 ? 12 : a.hour % 12;
      final period = a.hour >= 12 ? 'PM' : 'AM';
      final minuteStr = a.minute == 0 ? '' : ' and ${a.minute} minutes';
      buffer.write('Your next alarm is set for $hour12 $minuteStr $period. ');
    } else {
      buffer.write('You have no active alarms scheduled. ');
    }

    if (state.pendingTasks.isEmpty) {
      buffer.write('Your agenda is completely clear with zero pending tasks. ');
    } else {
      buffer.write(
        'You have ${state.pendingTasks.length} pending task${state.pendingTasks.length > 1 ? 's' : ''}. Top priority: ${state.pendingTasks.first.title}. ',
      );
    }

    buffer.write(state.batteryStatus);

    await _assistantRepo.speak(buffer.toString());
    if (!isClosed) {
      emit(state.copyWith(isBriefingPlaying: false));
    }
  }

  Future<void> readTaskAloud(TaskEntity task) async {
    await _haptics.successNotification();
    final priorityText = 'Priority: ${task.priority}.';
    final dueText = task.dueDate != null
        ? 'Due: ${DateFormat('h:mm a').format(task.dueDate!.toLocal())}.'
        : 'No deadline.';
    await _assistantRepo.speak('${task.title}. $priorityText $dueText');
  }

  Future<void> toggleTask(TaskEntity task) async {
    await _haptics.successNotification();
    await _tasksRepo.toggleTask(task);
    final status = task.isCompleted ? 'marked pending' : 'completed';
    await _assistantRepo.speak('Task $status: ${task.title}');
  }

  Future<void> toggleAlarm(AlarmEntity alarm) async {
    await _haptics.successNotification();
    await _focusRepo.toggleAlarm(alarm);
    final status = !alarm.isActive ? 'enabled' : 'disabled';
    final hourStr = alarm.hour.toString().padLeft(2, '0');
    final minStr = alarm.minute.toString().padLeft(2, '0');
    await _assistantRepo.speak('Alarm for $hourStr:$minStr $status.');
  }

  Future<void> readNextAlarmAloud(AlarmEntity? alarm) async {
    await _haptics.successNotification();
    if (alarm == null) {
      await _assistantRepo.speak('No active alarms scheduled for today.');
    } else {
      final hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12;
      final period = alarm.hour >= 12 ? 'PM' : 'AM';
      final minStr = alarm.minute == 0 ? "o'clock" : '${alarm.minute}';
      await _assistantRepo.speak(
        'Next upcoming alarm is at $hour12 $minStr $period labeled ${alarm.label}.',
      );
    }
  }

  Future<void> readMemoAloud(VoiceMemoEntity memo) async {
    await _haptics.successNotification();
    await _assistantRepo.speak('Note titled: ${memo.title}. Content: ${memo.content}');
  }

  @override
  Future<void> close() {
    _batteryTimer?.cancel();
    _alarmsSub?.cancel();
    _tasksSub?.cancel();
    _memosSub?.cancel();
    return super.close();
  }
}