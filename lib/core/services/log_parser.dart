import 'dart:convert';
import 'package:archive/archive.dart';

class LogParser {
  String summarize(String log) {
    final lines = log.split('\n');
    final important = lines.where((l) {
      final lower = l.toLowerCase();
      return lower.contains('error') ||
          lower.contains('exception') ||
          lower.contains('failed') ||
          lower.contains('failure') ||
          lower.contains('what went wrong') ||
          lower.contains('compilation failed');
    }).take(120).join('\n');
    return important.isEmpty ? '未提取到明确错误，请查看完整日志。' : important;
  }

  /// GitHub Actions logs are downloaded as a zip archive. Parsing the raw zip
  /// bytes as text produces garbled output and hides useful errors, so extract
  /// text-like entries first and then run the normal summarizer.
  String summarizeBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final buffer = StringBuffer();
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase();
        final textLike = name.endsWith('.txt') ||
            name.endsWith('.log') ||
            !name.contains('.');
        if (!textLike) continue;
        buffer
          ..writeln('===== ${file.name} =====')
          ..writeln(utf8.decode(file.content as List<int>, allowMalformed: true));
      }
      if (buffer.isNotEmpty) return summarize(buffer.toString());
    } catch (_) {
      // Fall back to best-effort plain text decoding below.
    }
    return summarize(utf8.decode(bytes, allowMalformed: true));
  }
}