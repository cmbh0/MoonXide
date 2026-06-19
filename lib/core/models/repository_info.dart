class RepositoryInfo {
  final String owner;
  final String name;
  final bool private;
  final String? description;
  final String? defaultBranch;

  const RepositoryInfo({
    required this.owner,
    required this.name,
    required this.private,
    this.description,
    this.defaultBranch,
  });
}