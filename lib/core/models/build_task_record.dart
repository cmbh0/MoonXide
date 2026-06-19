class BuildTaskRecord {
  final String repo;
  final String profile;
  final String status;
  final String? runUrl;
  final String? artifactUrl;
  final String? localPath;

  const BuildTaskRecord({
    required this.repo,
    required this.profile,
    required this.status,
    this.runUrl,
    this.artifactUrl,
    this.localPath,
  });
}