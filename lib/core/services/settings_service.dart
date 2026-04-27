import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.apiEndpoint,
    required this.foregroundReliabilityMode,
    required this.maxAttempts,
  });

  final String apiEndpoint;
  final bool foregroundReliabilityMode;
  final int maxAttempts;

  AppSettings copyWith({
    String? apiEndpoint,
    bool? foregroundReliabilityMode,
    int? maxAttempts,
  }) {
    return AppSettings(
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
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
  static const String _kForegroundMode = 'foreground_mode';
  static const String _kMaxAttempts = 'max_attempts';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiEndpoint: prefs.getString(_kApiEndpoint) ?? '',
      foregroundReliabilityMode: prefs.getBool(_kForegroundMode) ?? false,
      maxAttempts: prefs.getInt(_kMaxAttempts) ?? 12,
    );
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiEndpoint, settings.apiEndpoint.trim());
    await prefs.setBool(_kForegroundMode, settings.foregroundReliabilityMode);
    await prefs.setInt(_kMaxAttempts, settings.maxAttempts);
  }
}
