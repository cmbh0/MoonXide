import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider_config.dart';

class AiConfigStore {
  static const _key = 'moonxide.ai.provider.config';

  Future<void> save(AiProviderConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }

  Future<AiProviderConfig> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return AiProviderConfig.defaults();
    return AiProviderConfig.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
  }
}