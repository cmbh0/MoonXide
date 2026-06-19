class ChatMemorySnapshot {
  final String conversationId;
  final String summary;
  final String rawText;

  const ChatMemorySnapshot({required this.conversationId, required this.summary, required this.rawText});

  String asPromptAttachment() {
    return '以下是当前对话记忆文件内容，请作为上下文参考：\n$rawText\n\n对话压缩摘要：\n$summary';
  }
}