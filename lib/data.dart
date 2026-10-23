import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// One VPN Gate relay server, parsed from the public API CSV.
/// Country fields come straight from the API — never inferred.
class VpnServer {
  final String hostName;
  final String ip;
  final int score;
  final int ping; // ms (0 = unknown)
  final int speed; // bps
  final String countryLong;
  final String countryShort; // ISO code, uppercase
  final int sessions;
  final String operatorName;
  final String configB64;

  const VpnServer({
    required this.hostName,
    required this.ip,
    required this.score,
    required this.ping,
    required this.speed,
    required this.countryLong,
    required this.countryShort,
    required this.sessions,
    required this.operatorName,
    required this.configB64,
  });

  String get id => '$hostName|$ip';
  double get speedMbps => speed / 1000000.0;
  String get flagAsset => 'assets/flags/${countryShort.toLowerCase()}.png';

  /// The decoded OpenVPN config, or null if the payload is unusable.
  String? get decodedConfig {
    try {
      final text = utf8.decode(base64Decode(configB64));
      return text.contains('<ca>') ? text : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'h': hostName,
        'ip': ip,
        's': score,
        'p': ping,
        'v': speed,
        'cl': countryLong,
        'cs': countryShort,
        'n': sessions,
        'o': operatorName,
        'c': configB64,
      };

  factory VpnServer.fromJson(Map<String, dynamic> j) => VpnServer(
        hostName: j['h'] as String,
        ip: j['ip'] as String,
        score: (j['s'] as num).toInt(),
        ping: (j['p'] as num).toInt(),
        speed: (j['v'] as num).toInt(),
        countryLong: j['cl'] as String,
        countryShort: j['cs'] as String,
        sessions: (j['n'] as num).toInt(),
        operatorName: (j['o'] as String?) ?? '',
        configB64: j['c'] as String,
      );
}

/// Fetches, parses and caches the LIVE VPN Gate server list.
/// The list is never hardcoded; the cache only survives app restarts
/// until the next successful refresh.
class ServerRepository {
  ServerRepository._();
  static final ServerRepository instance = ServerRepository._();

  static const _apiUrl = 'https://www.vpngate.net/api/iphone/';
  static const _cacheKey = 'vpngate_servers_json';
  static const _cacheTsKey = 'vpngate_servers_ts';

  List<VpnServer> servers = [];
  DateTime? lastUpdated;
  bool loading = false;
  String? lastError;

  /// Parse the VPN Gate CSV. Format: comment lines start with '*',
  /// the header line starts with '#'. Data rows are comma-separated;
  /// the Operator/Message fields may themselves contain commas, so the
  /// fixed fields are read positionally from the start and the OpenVPN
  /// config (base64, comma-free) is always the LAST field.
  static List<VpnServer> parseCsv(String body) {
    final out = <VpnServer>[];
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('*') || line.startsWith('#')) {
        continue;
      }
      final parts = line.split(',');
      if (parts.length < 15) continue;
      final config = parts.last.trim();
      if (config.length < 100) continue;
      final s = VpnServer(
        hostName: parts[0].trim(),
        ip: parts[1].trim(),
        score: int.tryParse(parts[2].trim()) ?? 0,
        ping: int.tryParse(parts[3].trim()) ?? 0,
        speed: int.tryParse(parts[4].trim()) ?? 0,
        countryLong: parts[5].trim(),
        countryShort: parts[6].trim().toUpperCase(),
        sessions: int.tryParse(parts[7].trim()) ?? 0,
        operatorName: parts.length > 12 ? parts[12].trim() : '',
        configB64: config,
      );
      if (s.hostName.isEmpty || s.ip.isEmpty || s.countryShort.isEmpty) {
        continue;
      }
      if (s.decodedConfig == null) continue; // keep only usable servers
      out.add(s);
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => VpnServer.fromJson(e as Map<String, dynamic>))
            .toList();
        servers = list;
        if (ts != null) {
          lastUpdated = DateTime.fromMillisecondsSinceEpoch(ts);
        }
      }
    } catch (e) {
      debugPrint('SecureNet: server cache load failed: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode(servers.map((s) => s.toJson()).toList()));
      if (lastUpdated != null) {
        await prefs.setInt(
            _cacheTsKey, lastUpdated!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('SecureNet: server cache save failed: $e');
    }
  }

  /// Fetch the live list. Returns true on success.
  Future<bool> refresh() async {
    loading = true;
    lastError = null;
    try {
      final resp = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 45));
      if (resp.statusCode != 200) {
        lastError = 'Server list request failed (HTTP ${resp.statusCode})';
        loading = false;
        return false;
      }
      final parsed = parseCsv(resp.body);
      if (parsed.isEmpty) {
        lastError = 'No usable servers in the live list right now';
        loading = false;
        return false;
      }
      servers = parsed;
      lastUpdated = DateTime.now();
      await _saveCache();
      loading = false;
      return true;
    } catch (e) {
      lastError = 'Could not fetch the server list. Check your connection.';
      debugPrint('SecureNet: server refresh failed: $e');
      loading = false;
      return false;
    }
  }

  VpnServer? byId(String? id) {
    if (id == null) return null;
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Fastest = lowest ping among servers with a usable speed rating.
  VpnServer? get fastest {
    VpnServer? best;
    for (final s in servers) {
      if (s.ping <= 0) continue;
      if (best == null || s.ping < best.ping) best = s;
    }
    return best ?? (servers.isNotEmpty ? servers.first : null);
  }

  /// Build 2 (user order): ONE best server per country.
  /// [servers] arrives sorted by the VPN Gate quality score, which blends
  /// line speed, ping, uptime and load — so the first server seen for each
  /// country IS that country's best. The result stays score-ordered.
  List<VpnServer> get bestPerCountry {
    final seen = <String>{};
    final out = <VpnServer>[];
    for (final s in servers) {
      if (seen.add(s.countryShort)) out.add(s);
    }
    return out;
  }

  /// The best server for one country code (from [bestPerCountry]).
  VpnServer? bestForCountry(String? code) {
    if (code == null) return null;
    for (final s in bestPerCountry) {
      if (s.countryShort == code) return s;
    }
    return null;
  }
}

/// One-shot IP geolocation (city) for the selected server only.
/// Uses freeipapi.com over HTTPS; any failure just yields null and the
/// UI falls back to the API-provided country.
class CityLookup {
  static final Map<String, String?> _cache = {};

  static Future<String?> cityFor(String ip) async {
    if (_cache.containsKey(ip)) return _cache[ip];
    String? city;
    try {
      final resp = await http
          .get(Uri.parse('https://freeipapi.com/api/json/$ip'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final c = (j['city'] as String?)?.trim();
        if (c != null && c.isNotEmpty) city = c;
      }
    } catch (e) {
      debugPrint('SecureNet: city lookup failed: $e');
    }
    _cache[ip] = city;
    return city;
  }
}
