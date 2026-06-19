import 'chat_role.dart';

class ChatMessageRecord {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final String provider;
  final String modelId;
  final bool streaming;
  final bool taskOpen;

  const ChatMessageRecord({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.provider = '',
    this.modelId = '',
    this.streaming = false,
    this.taskOpen = false,
  });

  ChatMessageRecord copyWith({String? content, bool? streaming, bool? taskOpen}) {
    return ChatMessageRecord(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      provider: provider,
      modelId: modelId,
      streaming: streaming ?? this.streaming,
      taskOpen: taskOpen ?? this.taskOpen,
    );
  }

  String toTxtBlock() {
    final meta = '[${createdAt.toIso8601String()}] ${role.value}${provider.isEmpty ? '' : ' provider=$provider'}${modelId.isEmpty ? '' : ' model=$modelId'}';
    return '$meta\n$content\n---';
  }
}