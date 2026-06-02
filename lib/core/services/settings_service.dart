import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.apiEndpoint,
    required this.foregroundReliabilityMode,
    required this.maxAttempts,
    required this.portalDeviceId,
    required this.portalDeviceSecret,
    required this.portalPin,
    required this.portalPairedAt,
    required this.portalLastInboxSyncAt,
  });

  final String apiEndpoint;
  final bool foregroundReliabilityMode;
  final int maxAttempts;
  final String portalDeviceId;
  final String portalDeviceSecret;
  final String portalPin;
  final int portalPairedAt;
  final int portalLastInboxSyncAt;

  AppSettings copyWith({
    String? apiEndpoint,
    bool? foregroundReliabilityMode,
    int? maxAttempts,
    String? portalDeviceId,
    String? portalDeviceSecret,
    String? portalPin,
    int? portalPairedAt,
    int? portalLastInboxSyncAt,
  }) {
    return AppSettings(
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      foregroundReliabilityMode:
          foregroundReliabilityMode ?? this.foregroundReliabilityMode,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      portalDeviceId: portalDeviceId ?? this.portalDeviceId,
      portalDeviceSecret: portalDeviceSecret ?? this.portalDeviceSecret,
      portalPin: portalPin ?? this.portalPin,
      portalPairedAt: portalPairedAt ?? this.portalPairedAt,
      portalLastInboxSyncAt: portalLastInboxSyncAt ?? this.portalLastInboxSyncAt,
    );
  }
}

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String _kApiEndpoint = 'api_endpoint';
  static const String _kForegroundMode = 'foreground_mode';
  static const String _kMaxAttempts = 'max_attempts';
  static const String _kPortalDeviceId = 'portal_device_id';
  static const String _kPortalDeviceSecret = 'portal_device_secret';
  static const String _kPortalPin = 'portal_pin';
  static const String _kPortalPairedAt = 'portal_paired_at';
  static const String _kPortalLastInboxSyncAt = 'portal_last_inbox_sync_at';
  static const String _kInboxImported = 'inbox_imported';

  Future<AppSettings> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiEndpoint: prefs.getString(_kApiEndpoint) ?? '',
      foregroundReliabilityMode: prefs.getBool(_kForegroundMode) ?? false,
      maxAttempts: prefs.getInt(_kMaxAttempts) ?? 12,
      portalDeviceId: prefs.getString(_kPortalDeviceId) ?? '',
      portalDeviceSecret: prefs.getString(_kPortalDeviceSecret) ?? '',
      portalPin: prefs.getString(_kPortalPin) ?? '',
      portalPairedAt: prefs.getInt(_kPortalPairedAt) ?? 0,
      portalLastInboxSyncAt: prefs.getInt(_kPortalLastInboxSyncAt) ?? 0,
    );
  }

  Future<void> save(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiEndpoint, settings.apiEndpoint.trim());
    await prefs.setBool(_kForegroundMode, settings.foregroundReliabilityMode);
    await prefs.setInt(_kMaxAttempts, settings.maxAttempts);
    await prefs.setString(_kPortalDeviceId, settings.portalDeviceId.trim());
    await prefs.setString(
      _kPortalDeviceSecret,
      settings.portalDeviceSecret.trim(),
    );
    await prefs.setString(_kPortalPin, settings.portalPin.trim());
    await prefs.setInt(_kPortalPairedAt, settings.portalPairedAt);
    await prefs.setInt(_kPortalLastInboxSyncAt, settings.portalLastInboxSyncAt);
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
