import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'chat_message_record.dart';

class ChatMemoryFileStore {
  Future<Directory> folder() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/moonxide_chat_memory');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<File> fileFor(String conversationId) async {
    final f = await folder();
    return File('${f.path}/$conversationId.txt');
  }

  Future<List<FileSystemEntity>> listFiles() async {
    final f = await folder();
    final files = await f.list().where((e) => e.path.endsWith('.txt')).toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  Future<void> delete(String conversationId) async {
    final file = await fileFor(conversationId);
    if (await file.exists()) await file.delete();
  }

  Future<String> read(String conversationId) async {
    final file = await fileFor(conversationId);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  Future<void> writeAll(String conversationId, List<ChatMessageRecord> messages, {String summary = ''}) async {
    final file = await fileFor(conversationId);
    final buffer = StringBuffer();
    if (summary.trim().isNotEmpty) {
      buffer.writeln('# 压缩摘要');
      buffer.writeln(summary.trim());
      buffer.writeln('---');
    }
    for (final m in messages) {
      buffer.writeln(m.toTxtBlock());
    }
    await file.writeAsString(buffer.toString(), flush: true);
  }

  Future<void> append(String conversationId, ChatMessageRecord message) async {
    final file = await fileFor(conversationId);
    await file.writeAsString('${message.toTxtBlock()}\n', mode: FileMode.append, flush: true);
  }
}