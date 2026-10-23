import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local settings + lifetime usage statistics (SharedPreferences).
class AppStore {
  AppStore._();
  static final AppStore instance = AppStore._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool _getBool(String key, bool def) => _prefs?.getBool(key) ?? def;
  Future<void> _setBool(String key, bool v) async {
    try {
      await _prefs?.setBool(key, v);
    } catch (e) {
      debugPrint('SecureNet: pref save failed: $e');
    }
  }

  // ---- onboarding / settings ----
  bool get seenOnboarding => _getBool('seen_onboarding', false);
  Future<void> setSeenOnboarding() => _setBool('seen_onboarding', true);

  bool get autoConnect => _getBool('auto_connect', false);
  Future<void> setAutoConnect(bool v) => _setBool('auto_connect', v);

  bool get killSwitch => _getBool('kill_switch', true);
  Future<void> setKillSwitch(bool v) => _setBool('kill_switch', v);

  bool get notifications => _getBool('notifications_pref', true);
  Future<void> setNotifications(bool v) => _setBool('notifications_pref', v);

  String get protocol => _prefs?.getString('protocol') ?? 'Auto (OpenVPN)';

  String? get lastServerId => _prefs?.getString('last_server_id');
  Future<void> setLastServerId(String id) async {
    try {
      await _prefs?.setString('last_server_id', id);
    } catch (_) {}
  }

  bool get notifAsked => _getBool('notif_asked', false);
  Future<void> setNotifAsked() => _setBool('notif_asked', true);

  /// Build 2: the country the user uses — pinned at the top of the
  /// Locations list and used as the default connection target.
  String? get pinnedCountry => _prefs?.getString('pinned_country');
  Future<void> setPinnedCountry(String code) async {
    try {
      await _prefs?.setString('pinned_country', code);
    } catch (_) {}
  }

  /// One-time battery-exemption prompt was shown (stable connection).
  bool get batteryAsked => _getBool('battery_asked', false);
  Future<void> setBatteryAsked() => _setBool('battery_asked', true);

  // ---- lifetime stats (Profile screen) ----
  int get totalSeconds => _prefs?.getInt('stat_seconds') ?? 0;
  int get totalBytesIn => _prefs?.getInt('stat_bytes_in') ?? 0;
  int get totalBytesOut => _prefs?.getInt('stat_bytes_out') ?? 0;
  int get sessionCount => _prefs?.getInt('stat_sessions') ?? 0;

  List<String> get countriesUsed =>
      _prefs?.getStringList('stat_countries') ?? const [];
  List<String> get daysUsed =>
      _prefs?.getStringList('stat_days') ?? const [];
  int get daysConnected => daysUsed.length;

  Future<void> recordSession({
    required int durationSec,
    required int bytesIn,
    required int bytesOut,
    required String countryCode,
  }) async {
    final p = _prefs;
    if (p == null) return;
    try {
      await p.setInt('stat_seconds', totalSeconds + durationSec);
      await p.setInt('stat_bytes_in', totalBytesIn + bytesIn);
      await p.setInt('stat_bytes_out', totalBytesOut + bytesOut);
      await p.setInt('stat_sessions', sessionCount + 1);
      final countries = [...countriesUsed];
      if (!countries.contains(countryCode)) {
        countries.add(countryCode);
        await p.setStringList('stat_countries', countries);
      }
      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final days = [...daysUsed];
      if (!days.contains(day)) {
        days.add(day);
        await p.setStringList('stat_days', days);
      }
    } catch (e) {
      debugPrint('SecureNet: session record failed: $e');
    }
  }
}

/// Format a byte count as KB / MB / GB.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Format bytes/sec as Mbps with one decimal.
String formatMbps(num bytesPerSec) {
  final mbps = bytesPerSec * 8 / 1000000;
  return mbps.toStringAsFixed(1);
}
