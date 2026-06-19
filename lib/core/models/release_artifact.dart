class ReleaseArtifact {
  final String version;
  final String downloadUrl;
  final String localPath;
  final bool installed;

  const ReleaseArtifact({
    required this.version,
    required this.downloadUrl,
    required this.localPath,
    required this.installed,
  });
}
