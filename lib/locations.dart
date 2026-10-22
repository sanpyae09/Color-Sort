import 'package:flutter/material.dart';

import 'data.dart';
import 'vpn.dart';
import 'widgets.dart';

enum _LocFilter { all, streaming, gaming, fastest }

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  String _query = '';
  _LocFilter _filter = _LocFilter.all;

  List<VpnServer> _visible() {
    final repo = ServerRepository.instance;
    List<VpnServer> list;
    switch (_filter) {
      case _LocFilter.all:
        list = [...repo.servers];
        break;
      case _LocFilter.streaming:
        list = repo.streamingPicks;
        break;
      case _LocFilter.gaming:
        list = repo.gamingPicks;
        break;
      case _LocFilter.fastest:
        list = [...repo.servers]
          ..sort((a, b) {
            final ap = a.ping <= 0 ? 1 << 30 : a.ping;
            final bp = b.ping <= 0 ? 1 << 30 : b.ping;
            return ap.compareTo(bp);
          });
        break;
    }
    if (list.isEmpty && repo.servers.isNotEmpty) {
      // Filter matched nothing (e.g. no sub-60ms relays right now):
      // fall back to everything sorted by ping rather than showing air.
      list = [...repo.servers]
        ..sort((a, b) => (a.ping <= 0 ? 1 << 30 : a.ping)
            .compareTo(b.ping <= 0 ? 1 << 30 : b.ping));
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((s) =>
              s.countryLong.toLowerCase().contains(q) ||
              s.hostName.toLowerCase().contains(q) ||
              s.countryShort.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _refresh() async {
    await ServerRepository.instance.refresh();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ServerRepository.instance;
    final vpn = VpnController.instance;
    final servers = _visible();
    return Container(
      decoration: Brand.screenGradient,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 2),
              child: Row(
                children: [
                  const Text('Locations',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (repo.lastUpdated != null)
                    Text(
                      'Updated ${_hhmm(repo.lastUpdated!)} · ${repo.servers.length} servers',
                      style: const TextStyle(
                          color: Brand.textDim, fontSize: 11.5),
                    ),
                  IconButton(
                    onPressed: repo.loading ? null : _refresh,
                    icon: repo.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Brand.cyan))
                        : const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search country or city...',
                  hintStyle: const TextStyle(color: Brand.textDim),
                  prefixIcon:
                      const Icon(Icons.search, color: Brand.textDim),
                  filled: true,
                  fillColor: Brand.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Brand.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Brand.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Brand.blue),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  _chip('All', _LocFilter.all),
                  _chip('Streaming', _LocFilter.streaming),
                  _chip('Gaming', _LocFilter.gaming),
                  _chip('Fastest', _LocFilter.fastest),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: repo.servers.isEmpty
                  ? _emptyState(repo)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: Brand.cyan,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                        itemCount: servers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = servers[i];
                          final isSel = vpn.currentServer?.id == s.id;
                          final isLive = isSel && vpn.isConnected;
                          return _serverRow(context, s, isSel, isLive);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _emptyState(ServerRepository repo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Brand.textDim, size: 44),
            const SizedBox(height: 12),
            Text(
              repo.loading
                  ? 'Fetching live servers…'
                  : (repo.lastError ??
                      'No servers yet. Pull to refresh.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14.5),
            ),
            const SizedBox(height: 16),
            if (!repo.loading)
              PrimaryButton(
                label: 'Refresh Servers',
                icon: Icons.refresh,
                onTap: _refresh,
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _LocFilter f) {
    final active = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _filter = f),
        labelStyle: TextStyle(
          color: active ? Colors.white : Brand.textDim,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Brand.card,
        selectedColor: Brand.blue,
        side: const BorderSide(color: Brand.border),
        showCheckmark: false,
      ),
    );
  }

  Widget _serverRow(
      BuildContext context, VpnServer s, bool isSel, bool isLive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          VpnController.instance.select(s);
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ServerDetailsPage(server: s)));
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: Brand.cardBox(
              color: isSel ? Brand.cardSoft : Brand.card),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isSel
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSel ? Brand.cyan : Brand.textDim,
                size: 20,
              ),
              const SizedBox(width: 10),
              FlagCircle(server: s, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.countryLong,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    Text(
                      isLive ? '${s.hostName} · Connected' : s.hostName,
                      style: TextStyle(
                          color: isLive ? Brand.green : Brand.textDim,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(s.ping > 0 ? '${s.ping} ms' : '— ms',
                  style:
                      const TextStyle(color: Brand.textDim, fontSize: 12.5)),
              const SizedBox(width: 7),
              SignalBars(ping: s.ping),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 8 — server details with a gradient header, live stats from the
/// API listing, honest feature rows and a Connect button.
class ServerDetailsPage extends StatelessWidget {
  final VpnServer server;
  const ServerDetailsPage({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    final vpn = VpnController.instance;
    return Scaffold(
      backgroundColor: Brand.bg0,
      body: AnimatedBuilder(
        animation: vpn,
        builder: (context, _) {
          final isThis = vpn.currentServer?.id == server.id;
          final connectedHere = isThis && vpn.isConnected;
          final busyHere = isThis && vpn.isBusy;
          return Container(
            decoration: Brand.screenGradient,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gradient header with the flag
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF123B7A), Color(0xFF0A1C40)],
                      ),
                      border: Border.all(color: Brand.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                            ),
                            const Spacer(),
                            Icon(
                              connectedHere
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: connectedHere
                                  ? Brand.red
                                  : Brand.textDim,
                              size: 21,
                            ),
                          ],
                        ),
                        FlagCircle(server: server, size: 84),
                        const SizedBox(height: 12),
                        Text(server.countryLong,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800)),
                        Text(server.hostName,
                            style: const TextStyle(
                                color: Brand.textDim, fontSize: 13)),
                        FutureBuilder<String?>(
                          future: CityLookup.cityFor(server.ip),
                          builder: (context, snap) {
                            final city = snap.data;
                            if (city == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('IP location: $city',
                                  style: const TextStyle(
                                      color: Brand.cyan, fontSize: 12.5)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        _miniStat('Ping',
                            server.ping > 0 ? '${server.ping}' : '—', 'ms'),
                        _miniStat('Download',
                            server.speedMbps.toStringAsFixed(1), 'Mbps'),
                        _miniStat('Upload', '—', 'Mbps'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: PrimaryButton(
                      label: connectedHere
                          ? 'Disconnect'
                          : (busyHere ? 'Connecting…' : 'Connect'),
                      icon: Icons.power_settings_new,
                      onTap: () {
                        if (connectedHere) {
                          vpn.disconnect();
                        } else {
                          vpn.connectTo(server);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text('Server Features',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      children: [
                        _feature(Icons.speed, 'High Speed Server',
                            '${server.speedMbps.toStringAsFixed(0)} Mbps listed capacity'),
                        _feature(Icons.live_tv, 'Optimized for Streaming',
                            server.ping > 0 && server.ping <= 90
                                ? 'Low ping (${server.ping} ms)'
                                : 'Standard latency'),
                        _feature(Icons.people_outline, 'Public Relay Server',
                            server.operatorName.isEmpty
                                ? 'Community-operated (VPN Gate)'
                                : server.operatorName),
                        _feature(Icons.lock_outline, 'AES-128-CBC Encryption',
                            'OpenVPN tunnel, certificate verified'),
                        _feature(Icons.bar_chart, 'Active Sessions',
                            '${server.sessions} users connected now'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniStat(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 3),
              Text(unit,
                  style:
                      const TextStyle(color: Brand.textDim, fontSize: 11)),
            ],
          ),
          Text(label,
              style: const TextStyle(color: Brand.textDim, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String title, String sub) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Brand.cardSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Brand.cyan, size: 19),
      ),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 14.5)),
      subtitle: Text(sub,
          style: const TextStyle(color: Brand.textDim, fontSize: 12)),
    );
  }
}
