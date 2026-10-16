// lib/agenda/cubit/agenda_cubit.dart
import 'dart:async';
import 'package:beacon_os/agenda/cubit/agenda_state.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:bloc/bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class AgendaCubit extends Cubit<AgendaState> {
  AgendaCubit({
    required TaskAgendaRepository taskRepository,
    required AssistantRepository assistantRepository,
    required SettingsRepository settingsRepository, // 👈 حقن مستودع الإعدادات
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

  StreamSubscription<List<Task>>? _tasksSub;
  StreamSubscription<List<VoiceMemo>>? _memosSub;

  void _initSubscriptions() {
    emit(state.copyWith(status: AgendaStatus.loading));

    _tasksSub = _taskRepo.watchTasks().listen((taskList) {
      emit(state.copyWith(status: AgendaStatus.success, tasks: taskList));
    });

    _memosSub = _taskRepo.watchMemos().listen((memoList) {
      emit(state.copyWith(status: AgendaStatus.success, memos: memoList));
    });
  }

  Future<void> toggleTask(Task task) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    await _taskRepo.toggleTask(task);

    final statusWord = task.isCompleted ? 'marked pending' : 'completed';
    await _assistant.speak('Task $statusWord: ${task.title}');

    // ⚡️ تفعيل الأرشفة التلقائية (Auto-Archive):
    // إذا اكتملت المهمة وكان الخيار مفعلاً، يتم نقلها للأرشيف (soft-delete) بعد 600ms
    if (!task.isCompleted) {
      final settings = await _settings.getSettings();
      if (settings.autoArchiveCompleted) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _taskRepo.deleteTask(task.id);
      }
    }
  }

  Future<void> addNewTask({
    required String title,
    DateTime? dueDate,
    String? priority, // اختياري ليأخذ القيمة من الإعدادات تلقائياً
  }) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.success);

    // ⚡️ تطبيق الأولوية الافتراضية المحددة في الإعدادات
    final settings = await _settings.getSettings();
    final effectivePriority = priority ?? settings.defaultPriority;

    await _taskRepo.createTask(
      title: title,
      dueDate: dueDate,
      priority: effectivePriority,
    );
    await _assistant.speak('Task created: $title with $effectivePriority priority.');
  }

  Future<void> deleteTask(Task task) async {
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

  Future<void> readTaskAloud(Task task) async {
    await _haptics.successNotification();
    final priorityText = 'Priority: ${task.priority}.';
    final statusText = task.isCompleted ? 'Completed.' : 'Pending.';

    // ⚡️ نطق موعد الاستحقاق فقط إذا كان مفعلاً في الإعدادات
    final settings = await _settings.getSettings();
    String dueText = '';

    if (settings.speakDueDatesAloud && task.dueDate != null) {
      final now = DateTime.now();
      final due = task.dueDate!;
      final timeStr = DateFormat('h:mm a').format(due);

      if (due.year == now.year && due.month == now.month && due.day == now.day) {
        dueText = 'Due today at $timeStr. ';
      } else {
        dueText = 'Due on ${DateFormat('EEEE, MMMM d, h:mm a').format(due)}. ';
      }
    }

    await _assistant.speak('${task.title}. $priorityText $dueText$statusText');
  }

  Future<void> readMemoAloud(VoiceMemo memo) async {
    await _haptics.successNotification();
    await _assistant.speak('Note titled: ${memo.title}. Content: ${memo.content}');
  }

  Future<void> deleteMemo(VoiceMemo memo) async {
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