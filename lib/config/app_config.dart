class AppConfig {
  /// Base URL for the Next.js backend.
  ///
  /// Production: https://backery-management.vercel.app
  /// Local Android emulator: http://10.0.2.2:3000
  /// Local dev server: http://localhost:3000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://backery-management.vercel.app',
  );
}
