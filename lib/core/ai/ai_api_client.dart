import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_api_mode.dart';
import 'ai_endpoint_normalizer.dart';
import 'ai_provider_config.dart';

class AiRequestBuilder {
  Map<String, dynamic> buildBody(AiProviderConfig config, String userText) {
    return buildBodyWithHistory(config, [], userText);
  }

  Map<String, dynamic> buildBodyWithHistory(AiProviderConfig config, List<Map<String, dynamic>> history, String userText) {
    final body = <String, dynamic>{};
    if (config.model.trim().isNotEmpty) body['model'] = config.model.trim();
    if (config.temperature.trim().isNotEmpty) body['temperature'] = double.tryParse(config.temperature.trim()) ?? config.temperature.trim();
    if (config.topP.trim().isNotEmpty) body['top_p'] = double.tryParse(config.topP.trim()) ?? config.topP.trim();
    if (config.maxTokens.trim().isNotEmpty) body['max_tokens'] = int.tryParse(config.maxTokens.trim()) ?? config.maxTokens.trim();
    if (config.stream) body['stream'] = true;

    switch (config.mode) {
      case AiApiMode.openAiChatCompletions:
        body['messages'] = [
          if (config.systemPrompt.trim().isNotEmpty) {'role': 'system', 'content': config.systemPrompt.trim()},
          ...history,
          {'role': 'user', 'content': userText},
        ];
        break;
      case AiApiMode.openAiResponses:
        if (config.systemPrompt.trim().isNotEmpty) body['instructions'] = config.systemPrompt.trim();
        body['input'] = userText;
        break;
      case AiApiMode.anthropicMessages:
        if (config.systemPrompt.trim().isNotEmpty) body['system'] = config.systemPrompt.trim();
        body['messages'] = [
          ...history,
          {'role': 'user', 'content': userText},
        ];
        break;
    }
    return body;
  }
}

class AiApiClient {
  final http.Client client;
  final AiEndpointNormalizer normalizer;
  final AiRequestBuilder builder;

  AiApiClient({http.Client? client, AiEndpointNormalizer? normalizer, AiRequestBuilder? builder})
      : client = client ?? http.Client(),
        normalizer = normalizer ?? AiEndpointNormalizer(),
        builder = builder ?? AiRequestBuilder();

  Future<String> send(AiProviderConfig config, String text) async {
    return sendWithHistory(config, [], text);
  }

  Future<String> sendWithHistory(AiProviderConfig config, List<Map<String, dynamic>> history, String text) async {
    final url = normalizer.actualUrl(baseUrl: config.baseUrl, endpointPath: config.endpointPath, mode: config.mode);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (config.apiKey.trim().isNotEmpty) headers['Authorization'] = 'Bearer ${config.apiKey.trim()}';
    if (config.mode == AiApiMode.anthropicMessages) {
      headers['anthropic-version'] = '2023-06-01';
      if (config.apiKey.trim().isNotEmpty) headers['x-api-key'] = config.apiKey.trim();
    }
    final body = builder.buildBodyWithHistory(config, history, text);
    final response = await client.post(Uri.parse(url), headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI 请求失败 ${response.statusCode}: ${response.body}');
    }
    return response.body;
  }
}