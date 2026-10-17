// packages/launcher_repository/lib/src/models/voice_memo_entity.dart
import 'package:equatable/equatable.dart';

class VoiceMemoEntity extends Equatable {
  const VoiceMemoEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, title, content, createdAt];
}