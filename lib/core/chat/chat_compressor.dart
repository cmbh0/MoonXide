import '../ai/ai_api_client.dart';
import '../ai/ai_provider_config.dart';

class ChatCompressor {
  final AiApiClient client;

  ChatCompressor({AiApiClient? client}) : client = client ?? AiApiClient();

  Future<String> compress({required AiProviderConfig config, required String text}) async {
    if (text.trim().isEmpty) return '';
    final prompt = '请压缩以下对话记忆，保留用户目标、已完成修改、重要决策、未解决问题和约束，省略重复寒暄：\n$text';
    try {
      return await client.send(config.copyWith(stream: false), prompt);
    } catch (_) {
      final clipped = text.length > 4000 ? text.substring(text.length - 4000) : text;
      return '自动压缩摘要：\n$clipped';
    }
  }
}