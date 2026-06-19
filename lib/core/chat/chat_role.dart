enum ChatRole { user, assistant, tool, system }

extension ChatRoleName on ChatRole {
  String get value {
    switch (this) {
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
      case ChatRole.tool:
        return 'tool';
      case ChatRole.system:
        return 'system';
    }
  }
}