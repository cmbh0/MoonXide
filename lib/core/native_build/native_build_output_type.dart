enum NativeBuildOutputType { executable, shellExecutable, sharedLibrary, staticLibrary }

extension NativeBuildOutputTypeText on NativeBuildOutputType {
  String get label {
    switch (this) {
      case NativeBuildOutputType.executable:
        return '二进制可执行文件';
      case NativeBuildOutputType.shellExecutable:
        return '带 .sh 后缀的二进制可执行文件';
      case NativeBuildOutputType.sharedLibrary:
        return '动态库 .so';
      case NativeBuildOutputType.staticLibrary:
        return '静态库 .a';
    }
  }

  String get cmakeLibraryKind {
    switch (this) {
      case NativeBuildOutputType.executable:
      case NativeBuildOutputType.shellExecutable:
        return 'EXECUTABLE';
      case NativeBuildOutputType.sharedLibrary:
        return 'SHARED';
      case NativeBuildOutputType.staticLibrary:
        return 'STATIC';
    }
  }

  String artifactName(String projectName) {
    switch (this) {
      case NativeBuildOutputType.shellExecutable:
        return '$projectName.sh';
      case NativeBuildOutputType.sharedLibrary:
        return 'lib$projectName.so';
      case NativeBuildOutputType.staticLibrary:
        return 'lib$projectName.a';
      case NativeBuildOutputType.executable:
        return projectName;
    }
  }
}