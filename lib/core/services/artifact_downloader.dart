import 'dart:io';
import 'package:dio/dio.dart';

class ArtifactDownloader {
  final Dio dio;

  ArtifactDownloader({Dio? dio}) : dio = dio ?? Dio();

  Future<String> download({required String url, required String token, required String fileName}) async {
    final outDir = Directory('/sdcard/Download/MoonXide');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final path = '${outDir.path}/$fileName';
    await dio.download(
      url,
      path,
      options: Options(headers: {'Authorization': 'Bearer $token', 'Accept': 'application/vnd.github+json'}),
    );
    return path;
  }
}