import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.apiEndpoint,
    this.apiSecret = '',
    required this.foregroundReliabilityMode,
    required this.maxAttempts,
  });

  final String apiEndpoint;
  final String apiSecret;
  final bool foregroundReliabilityMode;
  final int maxAttempts;

  AppSettings copyWith({
    String? apiEndpoint,
    String? apiSecret,
    bool? foregroundReliabilityMode,
    int? maxAttempts,
  }) {
    return AppSettings(
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      apiSecret: apiSecret ?? this.apiSecret,
      foregroundReliabilityMode:
          foregroundReliabilityMode ?? this.foregroundReliabilityMode,
      maxAttempts: maxAttempts ?? this.maxAttempts,
    );
  }
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String _kApiEndpoint = 'api_endpoint';
  static const String _kApiSecret = 'api_secret';
  static const String _kForegroundMode = 'foreground_mode';
  static const String _kMaxAttempts = 'max_attempts';
  static const String _kInboxImported = 'inbox_imported';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiEndpoint: prefs.getString(_kApiEndpoint) ?? '',
      apiSecret: prefs.getString(_kApiSecret) ?? '',
      foregroundReliabilityMode: prefs.getBool(_kForegroundMode) ?? false,
      maxAttempts: prefs.getInt(_kMaxAttempts) ?? 12,
    );
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiEndpoint, settings.apiEndpoint.trim());
    await prefs.setString(_kApiSecret, settings.apiSecret.trim());
    await prefs.setBool(_kForegroundMode, settings.foregroundReliabilityMode);
    await prefs.setInt(_kMaxAttempts, settings.maxAttempts);
  }

  Future<bool> hasImportedInbox() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kInboxImported) ?? false;
  }

  Future<void> markInboxImported() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInboxImported, true);
  }
}
