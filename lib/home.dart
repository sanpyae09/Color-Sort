import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'data.dart';
import 'store.dart';
import 'vpn.dart';
import 'widgets.dart';

/// Home — build 2, simplified per the user's order: power button, status,
/// the selected (best-of-country) server, live speeds, and — only while
/// connected — one compact session card. Everything else was removed.
class HomeScreen extends StatefulWidget {
  final VoidCallback onGoLocations;
  const HomeScreen({super.key, required this.onGoLocations});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _booted = false;
  bool _showBatteryCard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
    _checkBattery();
  }

  Future<void> _checkBattery() async {
    try {
      if (AppStore.instance.batteryAsked) return;
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted && mounted) {
        setState(() => _showBatteryCard = true);
      }
    } catch (_) {}
  }

  Future<void> _boot() async {
    if (_booted) return;
    _booted = true;
    final repo = ServerRepository.instance;
    final vpn = VpnController.instance;
    await vpn.init();
    if (repo.servers.isEmpty) {
      await repo.refresh();
      if (mounted) setState(() {});
    }
    // Default target: the user's pinned country's best server first,
    // then the last-used server, then the overall fastest.
    VpnServer? defaultTarget() =>
        repo.bestForCountry(AppStore.instance.pinnedCountry) ??
        repo.byId(AppStore.instance.lastServerId) ??
        repo.fastest;
    if (vpn.currentServer == null) {
      final sel = defaultTarget();
      if (sel != null) vpn.select(sel);
    }
    if (AppStore.instance.autoConnect && !vpn.isConnected) {
      final target = defaultTarget();
      if (target != null) vpn.connectTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = VpnController.instance;
    final repo = ServerRepository.instance;
    return AnimatedBuilder(
      animation: vpn,
      builder: (context, _) {
        final selected = vpn.currentServer ?? repo.fastest;
        final connected = vpn.isConnected;
        return Container(
          decoration: Brand.screenGradient,
          child: SafeArea(
            child: Column(
              children: [
                const AppHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        ConnectButton(
                          phase: vpn.phase,
                          onTap: () => _onPowerTap(selected),
                        ),
                        const SizedBox(height: 16),
                        _statusLine(vpn),
                        if (vpn.errorText != null &&
                            (vpn.phase == VpnPhase.error ||
                                vpn.phase == VpnPhase.denied)) ...[
                          const SizedBox(height: 10),
                          _errorCard(vpn.errorText!),
                        ],
                        const SizedBox(height: 18),
                        _serverCard(selected),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                icon: Icons.arrow_downward,
                                iconColor: Brand.green,
                                label: 'Download',
                                value: connected
                                    ? formatMbps(vpn.speedInBps)
                                    : (selected == null
                                        ? '—'
                                        : selected.speedMbps
                                            .toStringAsFixed(1)),
                                unit: 'Mbps',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                icon: Icons.arrow_upward,
                                iconColor: Brand.cyan,
                                label: 'Upload',
                                value: connected
                                    ? formatMbps(vpn.speedOutBps)
                                    : '—',
                                unit: 'Mbps',
                              ),
                            ),
                          ],
                        ),
                        if (connected && selected != null) ...[
                          const SizedBox(height: 12),
                          _sessionCard(vpn, selected),
                        ],
                        if (_showBatteryCard) ...[
                          const SizedBox(height: 12),
                          _batteryCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onPowerTap(VpnServer? selected) {
    final vpn = VpnController.instance;
    if (vpn.isConnected ||
        vpn.phase == VpnPhase.connecting ||
        vpn.phase == VpnPhase.reconnecting) {
      vpn.disconnect();
    } else if (selected != null) {
      vpn.connectTo(selected);
    } else {
      widget.onGoLocations();
    }
  }

  Widget _statusLine(VpnController vpn) {
    final (Color dot, String text) = switch (vpn.phase) {
      VpnPhase.connected => (Brand.green, 'Connected'),
      VpnPhase.connecting => (Brand.blue, 'Connecting…'),
      VpnPhase.reconnecting => (Brand.amber, 'Reconnecting…'),
      VpnPhase.disconnecting => (Brand.textDim, 'Disconnecting…'),
      VpnPhase.denied || VpnPhase.error => (Brand.red, 'Not Connected'),
      VpnPhase.disconnected => (Brand.red, 'Disconnected'),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: Brand.text,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      width: double.infinity,
      decoration: Brand.cardBox(color: const Color(0xFFFFE3E1)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Brand.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: Brand.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _serverCard(VpnServer? selected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onGoLocations,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: Brand.cardBox(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: selected == null
              ? const Row(
                  children: [
                    Icon(Icons.public, color: Brand.textDim),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Fetching live servers…',
                          style: TextStyle(color: Brand.text)),
                    ),
                    Icon(Icons.chevron_right, color: Brand.textDim),
                  ],
                )
              : Row(
                  children: [
                    FlagCircle(server: selected, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selected.countryLong,
                              style: const TextStyle(
                                  color: Brand.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text(selected.hostName,
                              style: const TextStyle(
                                  color: Brand.textDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    SignalBars(ping: selected.ping),
                    const SizedBox(width: 6),
                    Text(selected.ping > 0 ? '${selected.ping} ms' : '— ms',
                        style: const TextStyle(
                            color: Brand.textDim, fontSize: 12)),
                    const Icon(Icons.chevron_right, color: Brand.textDim),
                  ],
                ),
        ),
      ),
    );
  }

  /// One compact card while connected: time + data + exit IP.
  Widget _sessionCard(VpnController vpn, VpnServer server) {
    return Container(
      decoration: Brand.cardBox(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Brand.cardSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield, color: Brand.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Protected · IP ${server.ip}',
                    style: const TextStyle(
                        color: Brand.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                Text(
                    'Data ${formatBytes(vpn.bytesIn + vpn.bytesOut)}',
                    style: const TextStyle(
                        color: Brand.textDim, fontSize: 12)),
              ],
            ),
          ),
          Text(vpn.elapsedText,
              style: const TextStyle(
                  color: Brand.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// One-time stability prompt: phones with aggressive battery saving
  /// kill the VPN service in the background, which looks like the
  /// connection "dropping by itself".
  Widget _batteryCard() {
    return Container(
      decoration: Brand.cardBox(color: Brand.cardSoft),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.battery_saver_outlined,
              color: Brand.blue, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep the connection stable',
                    style: TextStyle(
                        color: Brand.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(
                  'Allow SecureNet to run without battery limits so the '
                  'phone cannot stop the VPN in the background.',
                  style: TextStyle(color: Brand.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await AppStore.instance.setBatteryAsked();
              try {
                await Permission.ignoreBatteryOptimizations.request();
              } catch (_) {}
              if (mounted) setState(() => _showBatteryCard = false);
            },
            child: const Text('Allow',
                style: TextStyle(
                    color: Brand.blue, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            onPressed: () async {
              await AppStore.instance.setBatteryAsked();
              if (mounted) setState(() => _showBatteryCard = false);
            },
            icon: const Icon(Icons.close, color: Brand.textDim, size: 18),
          ),
        ],
      ),
    );
  }
}
