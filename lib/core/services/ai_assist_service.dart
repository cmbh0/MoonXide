class AiAssistService {
  String explainBuildError(String log) {
    return '错误分析：\n$log\n\n建议：优先检查依赖版本、Gradle 配置、AndroidManifest 权限、Dart/Java/Kotlin 编译错误位置。';
  }

  String generateCommitMessage(String path) => 'Update $path by MoonXide';
}