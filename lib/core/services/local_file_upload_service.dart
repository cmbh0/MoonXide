import 'dart:io';
import 'package:file_picker/file_picker.dart';

class LocalFileUploadService {
  Future<PlatformFile?> pickOne() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<List<int>> bytesOf(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return File(file.path!).readAsBytes();
    throw Exception('无法读取文件内容');
  }
}