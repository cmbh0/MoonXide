enum AiApiMode {
  openAiChatCompletions,
  openAiResponses,
  anthropicMessages,
}

extension AiApiModeText on AiApiMode {
  String get label {
    switch (this) {
      case AiApiMode.openAiChatCompletions:
        return 'OpenAI Chat Completions';
      case AiApiMode.openAiResponses:
        return 'OpenAI Responses API';
      case AiApiMode.anthropicMessages:
        return 'Anthropic Messages API';
    }
  }

  String get defaultPath {
    switch (this) {
      case AiApiMode.openAiChatCompletions:
        return '/v1/chat/completions';
      case AiApiMode.openAiResponses:
        return '/v1/responses';
      case AiApiMode.anthropicMessages:
        return '/v1/messages';
    }
  }
}