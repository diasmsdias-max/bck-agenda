class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'BCK_API_URL',
    defaultValue: 'http://10.0.2.2:5080',
  );
}
