import 'ai_api_mode.dart';

class AiProviderConfig {
  final AiApiMode mode;
  final String baseUrl;
  final String endpointPath;
  final String apiKey;
  final String model;
  final String temperature;
  final String topP;
  final String maxTokens;
  final String systemPrompt;
  final bool stream;

  const AiProviderConfig({
    required this.mode,
    required this.baseUrl,
    required this.endpointPath,
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.topP,
    required this.maxTokens,
    required this.systemPrompt,
    required this.stream,
  });

  factory AiProviderConfig.defaults() {
    return const AiProviderConfig(
      mode: AiApiMode.openAiChatCompletions,
      baseUrl: 'https://api.openai.com',
      endpointPath: '/v1/chat/completions',
      apiKey: '',
      model: 'gpt-4o-mini',
      temperature: '',
      topP: '',
      maxTokens: '',
      systemPrompt: '',
      stream: true,
    );
  }

  AiProviderConfig copyWith({
    AiApiMode? mode,
    String? baseUrl,
    String? endpointPath,
    String? apiKey,
    String? model,
    String? temperature,
    String? topP,
    String? maxTokens,
    String? systemPrompt,
    bool? stream,
  }) {
    return AiProviderConfig(
      mode: mode ?? this.mode,
      baseUrl: baseUrl ?? this.baseUrl,
      endpointPath: endpointPath ?? this.endpointPath,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      stream: stream ?? this.stream,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'baseUrl': baseUrl,
        'endpointPath': endpointPath,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'topP': topP,
        'maxTokens': maxTokens,
        'systemPrompt': systemPrompt,
        'stream': stream,
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      mode: AiApiMode.values.firstWhere((e) => e.name == json['mode'], orElse: () => AiApiMode.openAiChatCompletions),
      baseUrl: json['baseUrl']?.toString() ?? '',
      endpointPath: json['endpointPath']?.toString() ?? '',
      apiKey: json['apiKey']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      temperature: json['temperature']?.toString() ?? '',
      topP: json['topP']?.toString() ?? '',
      maxTokens: json['maxTokens']?.toString() ?? '',
      systemPrompt: json['systemPrompt']?.toString() ?? '',
      stream: json['stream'] == true,
    );
  }
}