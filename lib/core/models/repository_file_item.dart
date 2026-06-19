class RepositoryFileItem {
  final String path;
  final String name;
  final bool isDir;
  final String? sha;
  final String? downloadUrl;

  const RepositoryFileItem({
    required this.path,
    required this.name,
    required this.isDir,
    this.sha,
    this.downloadUrl,
  });
}