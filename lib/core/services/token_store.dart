import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TokenStore {
  static const _fileName = 'github_token.txt';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> saveToken(String token) async {
    final file = await _file();
    await file.writeAsString(token, flush: true);
  }

  Future<String?> readToken() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final value = await file.readAsString();
    return value.trim().isEmpty ? null : value.trim();
  }

  Future<void> clearToken() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}