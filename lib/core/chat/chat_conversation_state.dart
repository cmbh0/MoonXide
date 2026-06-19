import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../ai/ai_config_state.dart';
import '../ai/ai_api_mode.dart';
import 'chat_compressor.dart';
import 'chat_memory_file_store.dart';
import 'chat_memory_snapshot.dart';
import 'chat_message_record.dart';
import 'chat_role.dart';

class ChatConversationState extends ChangeNotifier {
  final ChatMemoryFileStore store;
  final ChatCompressor compressor;
  String conversationId;
  final int compressEvery;

  List<ChatMessageRecord> messages = [];
  String summary = '';
  bool busy = false;

  ChatConversationState({ChatMemoryFileStore? store, ChatCompressor? compressor, String? conversationId, this.compressEvery = 16})
      : store = store ?? ChatMemoryFileStore(),
        compressor = compressor ?? ChatCompressor(),
        conversationId = conversationId ?? const Uuid().v4();

  Future<void> sendUserText(String text, AiConfigState aiConfig) async {
    if (text.trim().isEmpty || busy) return;
    busy = true;
    _add(ChatMessageRecord(id: const Uuid().v4(), role: ChatRole.user, content: text.trim(), createdAt: DateTime.now()));
    final provider = aiConfig.config.mode.label;
    final model = aiConfig.config.model;
    final assistant = ChatMessageRecord(
      id: const Uuid().v4(),
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      provider: provider,
      modelId: model,
      streaming: aiConfig.config.stream,
      taskOpen: true,
    );
    _replaceOrAddAssistantBubble(assistant);
    await _persist();
    notifyListeners();
  }

  void appendAssistantDelta(String delta) {
    final index = messages.lastIndexWhere((e) => e.role == ChatRole.assistant && e.taskOpen);
    if (index < 0) return;
    messages[index] = messages[index].copyWith(content: messages[index].content + delta, streaming: true);
    notifyListeners();
  }

  Future<void> addToolResult(String content) async {
    final index = messages.lastIndexWhere((e) => e.role == ChatRole.assistant && e.taskOpen);
    if (index >= 0) {
      messages[index] = messages[index].copyWith(content: '${messages[index].content}\n\n[工具返回]\n$content');
    }
    await _persist();
    notifyListeners();
  }

  Future<void> finishAssistantTask(AiConfigState aiConfig) async {
    final index = messages.lastIndexWhere((e) => e.role == ChatRole.assistant && e.taskOpen);
    if (index >= 0) messages[index] = messages[index].copyWith(streaming: false, taskOpen: false);
    busy = false;
    await _autoCompress(aiConfig);
    await _persist();
    notifyListeners();
  }

  void newConversation() {
    conversationId = const Uuid().v4();
    messages.clear();
    summary = '';
    busy = false;
    notifyListeners();
  }

  Future<void> loadHistoryAsContext(String conversationId) async {
    final text = await store.read(conversationId);
    if (text.trim().isEmpty) return;
    this.conversationId = conversationId;
    messages = [
      ChatMessageRecord(
        id: const Uuid().v4(),
        role: ChatRole.assistant,
        content: '已载入历史对话作为记忆上下文：\n\n```text\n${text.length > 6000 ? text.substring(0, 6000) : text}\n```',
        createdAt: DateTime.now(),
      )
    ];
    summary = text.length > 3000 ? text.substring(0, 3000) : text;
    notifyListeners();
  }

  Future<void> deleteHistory(String conversationId) async {
    await store.delete(conversationId);
    notifyListeners();
  }

  void rollbackLastMessage() {
    if (messages.isEmpty) return;
    final last = messages.removeLast();
    if (last.role == ChatRole.assistant &&
        messages.isNotEmpty &&
        messages.last.role == ChatRole.assistant) {
      messages.removeLast();
    }
    notifyListeners();
  }

  /// 回滚到指定消息节点（保留该消息，删除其之后的所有消息）。
  void rollbackToMessage(String id) {
    final idx = messages.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    messages = messages.sublist(0, idx + 1);
    busy = false;
    notifyListeners();
  }

  void editMessage(String id, String content) {
    final index = messages.indexWhere((e) => e.id == id);
    if (index < 0) return;
    messages[index] = messages[index].copyWith(content: content);
    _enforceNoDoubleAssistant();
    notifyListeners();
  }

  ChatMemorySnapshot snapshot() {
    final raw = messages.map((e) => e.toTxtBlock()).join('\n');
    return ChatMemorySnapshot(conversationId: conversationId, summary: summary, rawText: raw);
  }

  void _replaceOrAddAssistantBubble(ChatMessageRecord message) {
    final index = messages.lastIndexWhere((e) => e.role == ChatRole.assistant && e.taskOpen);
    if (index >= 0) {
      messages[index] = message;
    } else {
      if (messages.isNotEmpty && messages.last.role == ChatRole.assistant) messages.removeLast();
      messages.add(message);
    }
  }

  void _add(ChatMessageRecord message) {
    messages.add(message);
    _enforceNoDoubleAssistant();
  }

  void _enforceNoDoubleAssistant() {
    final fixed = <ChatMessageRecord>[];
    for (final m in messages) {
      if (fixed.isNotEmpty && fixed.last.role == ChatRole.assistant && m.role == ChatRole.assistant) {
        fixed[fixed.length - 1] = fixed.last.copyWith(content: '${fixed.last.content}\n${m.content}', streaming: m.streaming, taskOpen: m.taskOpen);
      } else {
        fixed.add(m);
      }
    }
    messages = fixed;
  }

  Future<void> _autoCompress(AiConfigState aiConfig) async {
    if (messages.length < compressEvery || messages.length % compressEvery != 0) return;
    final text = messages.map((e) => e.toTxtBlock()).join('\n');
    summary = await compressor.compress(config: aiConfig.config, text: text);
  }

  Future<void> _persist() => store.writeAll(conversationId, messages, summary: summary);
}