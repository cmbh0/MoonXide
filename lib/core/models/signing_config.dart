class SigningConfig {
  final String keystorePath;
  final String alias;
  final String storePassword;
  final String keyPassword;

  const SigningConfig({
    required this.keystorePath,
    required this.alias,
    required this.storePassword,
    required this.keyPassword,
  });
}