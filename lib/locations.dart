import 'package:flutter/material.dart';

import 'data.dart';
import 'store.dart';
import 'vpn.dart';
import 'widgets.dart';

/// Locations — build 2: exactly ONE best server per country (chosen by
/// the VPN Gate quality score). The user's country is remembered and
/// always pinned at the top. No filter chips — the list stays clean.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  String _query = '';

  List<VpnServer> _visible() {
    final repo = ServerRepository.instance;
    var list = repo.bestPerCountry;
    final pinned = AppStore.instance.pinnedCountry;
    if (pinned != null && list.length > 1) {
      // Pinned country first; the rest keep their quality order.
      list = [
        ...list.where((s) => s.countryShort == pinned),
        ...list.where((s) => s.countryShort != pinned),
      ];
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
    final pinned = AppStore.instance.pinnedCountry;
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
                          color: Brand.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (repo.lastUpdated != null)
                    Text(
                      'Updated ${_hhmm(repo.lastUpdated!)} · ${repo.bestPerCountry.length} countries',
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
                        : const Icon(Icons.refresh, color: Brand.text),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Brand.text, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search country...',
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
                          final isPinned = s.countryShort == pinned;
                          return _serverRow(context, s, isSel, isLive, isPinned);
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
                  : (repo.lastError ?? 'No servers yet. Pull to refresh.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.text, fontSize: 14.5),
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

  Widget _serverRow(BuildContext context, VpnServer s, bool isSel,
      bool isLive, bool isPinned) {
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
          decoration:
              Brand.cardBox(color: isSel ? Brand.cardSoft : Brand.card),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isPinned
                    ? Icons.push_pin
                    : (isSel
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                color: isPinned || isSel ? Brand.blue : Brand.textDim,
                size: 19,
              ),
              const SizedBox(width: 10),
              FlagCircle(server: s, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s.countryLong,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Brand.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Brand.blue,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text('YOUR COUNTRY',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4)),
                          ),
                        ],
                      ],
                    ),
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
                  style: const TextStyle(
                      color: Brand.textDim, fontSize: 12.5)),
              const SizedBox(width: 7),
              SignalBars(ping: s.ping),
            ],
          ),
        ),
      ),
    );
  }
}

/// Server details — the country's best server: live stats from the API
/// listing, a few honest facts and one Connect button.
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
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: Brand.primaryGradient,
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
                            const Text('BEST SERVER',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2)),
                            const SizedBox(width: 8),
                          ],
                        ),
                        FlagCircle(server: server, size: 80),
                        const SizedBox(height: 10),
                        Text(server.countryLong,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800)),
                        Text(server.hostName,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        FutureBuilder<String?>(
                          future: CityLookup.cityFor(server.ip),
                          builder: (context, snap) {
                            final city = snap.data;
                            if (city == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('IP location: $city',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5)),
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
                        _miniStat('Sessions', '${server.sessions}', ''),
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
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      children: [
                        _feature(Icons.speed, 'High Speed Server',
                            '${server.speedMbps.toStringAsFixed(0)} Mbps listed capacity'),
                        _feature(Icons.people_outline, 'Public Relay Server',
                            server.operatorName.isEmpty
                                ? 'Community-operated (VPN Gate)'
                                : server.operatorName),
                        _feature(Icons.lock_outline, 'Encrypted Tunnel',
                            'OpenVPN, certificate verified'),
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
                      color: Brand.text,
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
          style: const TextStyle(color: Brand.text, fontSize: 14.5)),
      subtitle: Text(sub,
          style: const TextStyle(color: Brand.textDim, fontSize: 12)),
    );
  }
}
