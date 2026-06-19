import 'package:flutter/foundation.dart';
import 'ai_api_mode.dart';
import 'ai_config_store.dart';
import 'ai_endpoint_normalizer.dart';
import 'ai_provider_config.dart';

class AiConfigState extends ChangeNotifier {
  final AiConfigStore store;
  final AiEndpointNormalizer normalizer;
  AiProviderConfig config = AiProviderConfig.defaults();
  bool loaded = false;

  AiConfigState({AiConfigStore? store, AiEndpointNormalizer? normalizer})
      : store = store ?? AiConfigStore(),
        normalizer = normalizer ?? AiEndpointNormalizer();

  Future<void> load() async {
    config = await store.read();
    loaded = true;
    notifyListeners();
  }

  String get actualUrl => normalizer.actualUrl(baseUrl: config.baseUrl, endpointPath: config.endpointPath, mode: config.mode);

  Future<void> update(AiProviderConfig next) async {
    config = next;
    await store.save(config);
    notifyListeners();
  }

  Future<void> setMode(AiApiMode mode) => update(config.copyWith(mode: mode, endpointPath: mode.defaultPath));
  Future<void> setBaseUrl(String value) => update(config.copyWith(baseUrl: normalizer.normalizeBaseUrl(value)));
  Future<void> setEndpointPath(String value) => update(config.copyWith(endpointPath: normalizer.normalizePath(value, config.mode)));
  Future<void> setApiKey(String value) => update(config.copyWith(apiKey: value));
  Future<void> setModel(String value) => update(config.copyWith(model: value));
  Future<void> setTemperature(String value) => update(config.copyWith(temperature: value));
  Future<void> setTopP(String value) => update(config.copyWith(topP: value));
  Future<void> setMaxTokens(String value) => update(config.copyWith(maxTokens: value));
  Future<void> setSystemPrompt(String value) => update(config.copyWith(systemPrompt: value));
  Future<void> setStream(bool value) => update(config.copyWith(stream: value));
}