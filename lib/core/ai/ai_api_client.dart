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
    // 用 utf8 解码 response.bodyBytes，防止 Dart 默认用 Latin-1 (ISO-8859-1) 造成乱码
    final decodedBody = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI 请求失败 ${response.statusCode}: $decodedBody');
    }
    return decodedBody;
  }

  /// 流式调用 AI API，返回逐 token 的 Stream<String>
  Stream<String> sendStream(AiProviderConfig config, String text) async* {
    yield* sendStreamWithHistory(config, [], text);
  }

  /// 带历史记录的流式调用 AI API
  Stream<String> sendStreamWithHistory(AiProviderConfig config, List<Map<String, dynamic>> history, String text) async* {
    final streamConfig = config.copyWith(stream: true);
    final url = normalizer.actualUrl(baseUrl: streamConfig.baseUrl, endpointPath: streamConfig.endpointPath, mode: streamConfig.mode);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (streamConfig.apiKey.trim().isNotEmpty) headers['Authorization'] = 'Bearer ${streamConfig.apiKey.trim()}';
    if (streamConfig.mode == AiApiMode.anthropicMessages) {
      headers['anthropic-version'] = '2023-06-01';
      if (streamConfig.apiKey.trim().isNotEmpty) headers['x-api-key'] = streamConfig.apiKey.trim();
    }
    final body = builder.buildBodyWithHistory(streamConfig, history, text);
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll(headers);
    request.body = jsonEncode(body);
    final streamedResponse = await client.send(request);
    
    if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
      final bodyStr = await streamedResponse.stream.bytesToString();
      throw Exception('AI 流式请求失败 ${streamedResponse.statusCode}: $bodyStr');
    }
    
    final buffer = StringBuffer();
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final lines = buffer.toString().split('\n');
      buffer.clear();
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        buffer.write(lines.removeLast());
      }
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data);
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {}
        }
      }
    }
  }
}