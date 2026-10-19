// lib/mobile/agenda/cubit/agenda_cubit.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/mobile/agenda/cubit/agenda_state.dart';
import 'package:bloc/bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

class AgendaCubit extends Cubit<AgendaState> {
  AgendaCubit({
    required TaskAgendaRepository taskRepository,
    required AssistantRepository assistantRepository,
    required SettingsRepository settingsRepository,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _taskRepo = taskRepository,
        _assistant = assistantRepository,
        _settings = settingsRepository,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const AgendaState()) {
    _initSubscriptions();
  }

  final TaskAgendaRepository _taskRepo;
  final AssistantRepository _assistant;
  final SettingsRepository _settings;
  final HapticManager _haptics;
  final SoundController _sound;

  StreamSubscription<List<TaskEntity>>? _tasksSub;
  StreamSubscription<List<VoiceMemoEntity>>? _memosSub;

  void _initSubscriptions() {
    emit(state.copyWith(status: AgendaStatus.loading));

    _tasksSub = _taskRepo.watchTasks().listen((taskList) {
      emit(state.copyWith(status: AgendaStatus.success, tasks: taskList));
    });

    _memosSub = _taskRepo.watchMemos().listen((memoList) {
      emit(state.copyWith(status: AgendaStatus.success, memos: memoList));
    });
  }

  Future<void> toggleTask(TaskEntity task) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    await _taskRepo.toggleTask(task);

    final statusWord = task.isCompleted ? 'marked pending' : 'completed';
    await _assistant.speak('Task $statusWord: ${task.title}');

    // 🛡️ ملاحظة هندسية حاسمة:
    // تم إلغاء استدعاء deleteTask التدميري هنا.
    // المهمة تظل محفوظة في الخزنة مع (isCompleted = true) لتظهر دائماً
    // في طابق الأرشيف (Floor -1) مع إمكانية استعادتها أو حذفها يدوياً.
  }

  Future<void> addNewTask({
    required String title,
    DateTime? dueDate,
    String? priority,
  }) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.success);

    final settings = await _settings.getSettings();
    final effectivePriority = priority ?? settings.defaultPriority;

    await _taskRepo.createTask(
      title: title,
      dueDate: dueDate?.toUtc(),
      priority: effectivePriority,
    );
    await _assistant.speak('Task created: $title with $effectivePriority priority.');
  }

  Future<void> deleteTask(TaskEntity task) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    await _taskRepo.deleteTask(task.id);
    await _assistant.speak('Task deleted.');
  }

  Future<void> addNewMemo({
    required String title,
    required String content,
  }) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.success);
    await _taskRepo.createMemo(title: title, content: content);
    await _assistant.speak('Note saved: $title');
  }

  Future<void> readTaskAloud(TaskEntity task) async {
    await _haptics.successNotification();
    final priorityText = 'Priority: ${task.priority}.';
    final statusText = task.isCompleted ? 'Completed.' : 'Pending.';

    final settings = await _settings.getSettings();
    String dueText = '';

    if (settings.speakDueDatesAloud && task.dueDate != null) {
      final now = DateTime.now();
      final due = task.dueDate!.toLocal();
      final timeStr = DateFormat('h:mm a').format(due);

      if (due.year == now.year && due.month == now.month && due.day == now.day) {
        dueText = 'Due today at $timeStr. ';
      } else {
        dueText = 'Due on ${DateFormat('EEEE, MMMM d, h:mm a').format(due)}. ';
      }
    }

    await _assistant.speak('${task.title}. $priorityText $dueText$statusText');
  }

  Future<void> readMemoAloud(VoiceMemoEntity memo) async {
    await _haptics.successNotification();
    await _assistant.speak('Note titled: ${memo.title}. Content: ${memo.content}');
  }

  Future<void> deleteMemo(VoiceMemoEntity memo) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    await _taskRepo.deleteMemo(memo.id);
    await _assistant.speak('Note deleted: ${memo.title}');
  }

  @override
  Future<void> close() {
    _tasksSub?.cancel();
    _memosSub?.cancel();
    return super.close();
  }
}