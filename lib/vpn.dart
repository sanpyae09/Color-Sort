import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'data.dart';
import 'store.dart';

enum VpnPhase {
  disconnected,
  connecting,
  connected,
  disconnecting,
  reconnecting,
  denied,
  error,
}

int _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

/// Single owner of the OpenVPN engine. UI reads state from here.
class VpnController extends ChangeNotifier {
  VpnController._();
  static final VpnController instance = VpnController._();

  OpenVPN? _engine;
  bool _initStarted = false;

  VpnPhase phase = VpnPhase.disconnected;

  /// The server the user selected (and, while connected, the tunnel peer).
  VpnServer? currentServer;

  String? errorText;

  /// True while the kill switch is holding a blocking "reconnecting"
  /// overlay after an unexpected drop.
  bool killSwitchBlock = false;

  int bytesIn = 0;
  int bytesOut = 0;
  int speedInBps = 0;
  int speedOutBps = 0;
  int elapsedSeconds = 0;

  DateTime? _connectedSince;
  Timer? _elapsedTimer;
  Timer? _reconnectTimer;
  bool _userInitiatedDisconnect = false;
  int _reconnectAttempts = 0;
  bool _sessionCounted = false;

  bool get isConnected => phase == VpnPhase.connected;
  bool get isBusy =>
      phase == VpnPhase.connecting ||
      phase == VpnPhase.disconnecting ||
      phase == VpnPhase.reconnecting;

  String get elapsedText {
    final h = (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    _engine = OpenVPN(
      onVpnStageChanged: _onStage,
      onVpnStatusChanged: _onStatus,
    );
    try {
      await _engine!.initialize(
        groupIdentifier: 'group.com.pyaystudios.securenet',
        providerBundleIdentifier: 'com.pyaystudios.securenet.VPNExtension',
        localizedDescription: 'SecureNet',
        lastStage: (stage) => _onStage(stage, ''),
        lastStatus: _onStatus,
      );
    } catch (e) {
      debugPrint('SecureNet: VPN engine init failed: $e');
    }
  }

  void _onStatus(VpnStatus? status) {
    if (status == null) return;
    bytesIn = _toInt(status.byteIn);
    bytesOut = _toInt(status.byteOut);
    speedInBps = _toInt(status.speedIn);
    speedOutBps = _toInt(status.speedOut);
    notifyListeners();
  }

  void _onStage(VPNStage stage, String raw) {
    final name = raw.toLowerCase();
    if (stage.isConnected || name == 'connected') {
      phase = VpnPhase.connected;
      killSwitchBlock = false;
      _reconnectAttempts = 0;
      _sessionCounted = false;
      _connectedSince ??= DateTime.now();
      _startElapsedTimer();
    } else if (name == 'denied') {
      phase = VpnPhase.denied;
      errorText = 'VPN permission was refused.';
      killSwitchBlock = false;
    } else if (name == 'reconnect' ||
        name == 'no_network' ||
        name == 'paused') {
      if (phase == VpnPhase.connected || phase == VpnPhase.reconnecting) {
        phase = VpnPhase.reconnecting;
        if (AppStore.instance.killSwitch) killSwitchBlock = true;
      }
    } else if (stage.isDisconnected ||
        name == 'disconnected' ||
        name == 'error' ||
        name == 'auth_failed' ||
        name == 'exiting') {
      _handleDrop(error: name == 'error' || name == 'auth_failed');
    } else {
      if (phase != VpnPhase.connected) phase = VpnPhase.connecting;
    }
    notifyListeners();
  }

  void _handleDrop({required bool error}) {
    final wasActive = phase == VpnPhase.connected ||
        phase == VpnPhase.connecting ||
        phase == VpnPhase.reconnecting;
    _finalizeSession();
    if (!_userInitiatedDisconnect &&
        wasActive &&
        AppStore.instance.killSwitch &&
        currentServer != null &&
        _reconnectAttempts < 5) {
      // Kill switch: hold the blocking overlay and retry the tunnel.
      phase = VpnPhase.reconnecting;
      killSwitchBlock = true;
      _reconnectAttempts++;
      notifyListeners();
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (phase == VpnPhase.reconnecting && currentServer != null) {
          _startEngine(currentServer!);
        }
      });
      return;
    }
    killSwitchBlock = false;
    phase = error ? VpnPhase.error : VpnPhase.disconnected;
    if (error && errorText == null) {
      errorText = 'The connection dropped. Please try again.';
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedSince != null) {
        elapsedSeconds = DateTime.now().difference(_connectedSince!).inSeconds;
        notifyListeners();
      }
    });
  }

  void _finalizeSession() {
    if (_connectedSince != null && !_sessionCounted) {
      _sessionCounted = true;
      final secs = DateTime.now().difference(_connectedSince!).inSeconds;
      if (secs >= 5 && currentServer != null) {
        AppStore.instance.recordSession(
          durationSec: secs,
          bytesIn: bytesIn,
          bytesOut: bytesOut,
          countryCode: currentServer!.countryShort,
        );
      }
    }
    _connectedSince = null;
    _elapsedTimer?.cancel();
    elapsedSeconds = 0;
    bytesIn = 0;
    bytesOut = 0;
    speedInBps = 0;
    speedOutBps = 0;
  }

  Future<void> _maybeRequestNotifications() async {
    try {
      final store = AppStore.instance;
      if (store.notifications && !store.notifAsked) {
        await Permission.notification.request();
        await store.setNotifAsked();
      }
    } catch (e) {
      debugPrint('SecureNet: notification permission failed: $e');
    }
  }

  /// Select a server without connecting (list tap / details view).
  void select(VpnServer server) {
    currentServer = server;
    AppStore.instance.setLastServerId(server.id);
    notifyListeners();
  }

  Future<void> connectTo(VpnServer server) async {
    await init();
    _userInitiatedDisconnect = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    currentServer = server;
    errorText = null;
    killSwitchBlock = false;
    await AppStore.instance.setLastServerId(server.id);
    await _maybeRequestNotifications();
    phase = VpnPhase.connecting;
    notifyListeners();
    await _startEngine(server);
  }

  Future<void> _startEngine(VpnServer server) async {
    final engine = _engine;
    if (engine == null) {
      phase = VpnPhase.error;
      errorText = 'VPN engine unavailable.';
      notifyListeners();
      return;
    }
    final config = server.decodedConfig;
    if (config == null) {
      phase = VpnPhase.error;
      errorText = 'This server\'s configuration is unusable. Try another.';
      notifyListeners();
      return;
    }
    try {
      final started = await engine.connect(
        config,
        '${server.countryShort} - ${server.hostName}',
      );
      if (!started) {
        phase = VpnPhase.denied;
        errorText = 'VPN permission was refused.';
        killSwitchBlock = false;
        notifyListeners();
      }
    } on PlatformException catch (e) {
      phase = VpnPhase.error;
      errorText = 'Connection failed (${e.code}). Try another server.';
      killSwitchBlock = false;
      notifyListeners();
    } catch (e) {
      phase = VpnPhase.error;
      errorText = 'Connection failed. Try another server.';
      killSwitchBlock = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    killSwitchBlock = false;
    phase = VpnPhase.disconnecting;
    notifyListeners();
    try {
      await _engine?.disconnect();
    } catch (_) {}
    _finalizeSession();
    phase = VpnPhase.disconnected;
    notifyListeners();
  }

  /// User dismissed the kill-switch overlay: stop retrying, disconnect.
  Future<void> cancelReconnect() async {
    _reconnectTimer?.cancel();
    await disconnect();
  }

  Future<void> openSystemVpnSettings() async {
    try {
      await _engine?.openVpnSettings();
    } catch (e) {
      debugPrint('SecureNet: openVpnSettings failed: $e');
    }
  }
}
