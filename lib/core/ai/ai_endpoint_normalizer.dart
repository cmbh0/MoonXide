import 'ai_api_mode.dart';

class AiEndpointNormalizer {
  String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String normalizePath(String input, AiApiMode mode) {
    var value = input.trim();
    if (value.isEmpty) return mode.defaultPath;
    if (!value.startsWith('/')) value = '/$value';
    return value;
  }

  String actualUrl({required String baseUrl, required String endpointPath, required AiApiMode mode}) {
    final base = normalizeBaseUrl(baseUrl);
    if (base.isEmpty) return '';
    final path = normalizePath(endpointPath, mode);
    return '$base$path';
  }
}