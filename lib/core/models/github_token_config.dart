class GitHubTokenConfig {
  final String token;
  final List<String> scopes;
  final bool accepted;

  const GitHubTokenConfig({
    required this.token,
    required this.scopes,
    required this.accepted,
  });
}
