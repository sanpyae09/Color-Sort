import 'package:flutter/material.dart';

import 'data.dart';
import 'settings.dart';
import 'store.dart';
import 'vpn.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onGoLocations;
  const HomeScreen({super.key, required this.onGoLocations});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
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
    // Restore the previous selection (or the fastest server).
    if (vpn.currentServer == null) {
      final last = repo.byId(AppStore.instance.lastServerId);
      final sel = last ?? repo.fastest;
      if (sel != null) vpn.select(sel);
    }
    // Auto Connect: join the last (or fastest) server on start.
    if (AppStore.instance.autoConnect && !vpn.isConnected) {
      final target = repo.byId(AppStore.instance.lastServerId) ?? repo.fastest;
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
                AppHeader(
                  onCrown: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PremiumPage())),
                  onProfile: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage())),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 12),
                        if (connected) ...[
                          _connectionTimeCard(vpn),
                          const SizedBox(height: 12),
                        ],
                        _privacyCard(vpn, selected),
                        const SizedBox(height: 12),
                        _quickConnectCard(repo),
                        const SizedBox(height: 12),
                        _streamingCard(),
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      width: double.infinity,
      decoration: Brand.cardBox(color: const Color(0xFF3A1430)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Brand.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
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
                          style: TextStyle(color: Colors.white)),
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
                                  color: Colors.white,
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
                    Text(
                        selected.ping > 0 ? '${selected.ping} ms' : '— ms',
                        style: const TextStyle(
                            color: Brand.textDim, fontSize: 12)),
                    const Icon(Icons.chevron_right, color: Brand.textDim),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _connectionTimeCard(VpnController vpn) {
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
            child: const Icon(Icons.timer_outlined,
                color: Brand.green, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Connection Time',
              style: TextStyle(color: Brand.textDim, fontSize: 13)),
          const Spacer(),
          Text(vpn.elapsedText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          Text(formatBytes(vpn.bytesIn + vpn.bytesOut),
              style: const TextStyle(color: Brand.textDim, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _privacyCard(VpnController vpn, VpnServer? selected) {
    final connected = vpn.isConnected;
    return Container(
      decoration: Brand.cardBox(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            connected ? Icons.shield : Icons.shield_outlined,
            color: connected ? Brand.green : Brand.textDim,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected
                      ? 'Your Privacy is Protected'
                      : 'Your Privacy is Exposed',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  connected && selected != null
                      ? 'IP Address: ${selected.ip}'
                      : 'Tap the button to secure your connection',
                  style:
                      const TextStyle(color: Brand.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickConnectCard(ServerRepository repo) {
    final fastest = repo.fastest;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: fastest == null
            ? null
            : () => VpnController.instance.connectTo(fastest),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: Brand.cardBox(color: Brand.cardSoft),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: Brand.gold, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Connect',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text(
                      fastest == null
                          ? 'No servers loaded yet'
                          : 'Fastest Server · ${fastest.countryLong}',
                      style: const TextStyle(
                          color: Brand.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Brand.textDim),
            ],
          ),
        ),
      ),
    );
  }

  Widget _streamingCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StreamingPage())),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: Brand.cardBox(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: const Row(
            children: [
              Icon(Icons.live_tv, color: Brand.cyan, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Streaming Mode',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text('Low-ping servers for smooth streaming',
                        style:
                            TextStyle(color: Brand.textDim, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Brand.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
