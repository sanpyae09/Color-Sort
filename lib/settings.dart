import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'store.dart';
import 'vpn.dart';
import 'widgets.dart';

/// Settings — build 2, trimmed to what matters: the three switches, a
/// battery-stability row, protocol info, system VPN settings, support.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Container(
      decoration: Brand.screenGradient,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Text('Settings',
                  style: TextStyle(
                      color: Brand.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  _sectionLabel('General'),
                  _switchRow(
                    icon: Icons.bolt_outlined,
                    title: 'Auto Connect',
                    subtitle: 'Connect automatically when the app starts',
                    value: store.autoConnect,
                    onChanged: (v) async {
                      await store.setAutoConnect(v);
                      setState(() {});
                    },
                  ),
                  _switchRow(
                    icon: Icons.shield_outlined,
                    title: 'Kill Switch',
                    subtitle:
                        'Block the screen while an interrupted tunnel reconnects',
                    value: store.killSwitch,
                    onChanged: (v) async {
                      await store.setKillSwitch(v);
                      setState(() {});
                    },
                  ),
                  _switchRow(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Connection status notifications',
                    value: store.notifications,
                    onChanged: (v) async {
                      await store.setNotifications(v);
                      setState(() {});
                    },
                  ),
                  _sectionLabel('Connection'),
                  FutureBuilder<PermissionStatus>(
                    future: Permission.ignoreBatteryOptimizations.status,
                    builder: (context, snap) {
                      final granted = snap.data?.isGranted ?? false;
                      return MenuRow(
                        icon: Icons.battery_saver_outlined,
                        title: 'Stable Connection',
                        subtitle: granted
                            ? 'Battery limits off — the VPN can run in the background'
                            : 'Allow no battery limits so the phone cannot stop the VPN',
                        trailing: Text(granted ? 'On' : 'Set up',
                            style: TextStyle(
                                color: granted
                                    ? Brand.green
                                    : Brand.blue,
                                fontWeight: FontWeight.w700)),
                        onTap: granted
                            ? null
                            : () async {
                                try {
                                  await Permission
                                      .ignoreBatteryOptimizations
                                      .request();
                                } catch (_) {}
                                if (mounted) setState(() {});
                              },
                      );
                    },
                  ),
                  MenuRow(
                    icon: Icons.tune,
                    title: 'Protocol',
                    subtitle: store.protocol,
                    trailing: const Text('Auto',
                        style: TextStyle(color: Brand.textDim)),
                    onTap: () => _infoDialog(
                      'Protocol',
                      'SecureNet connects with OpenVPN — the protocol '
                          'provided by every server in the live list. '
                          'Encryption and port are taken from each '
                          'server\'s own configuration.',
                    ),
                  ),
                  MenuRow(
                    icon: Icons.vpn_lock_outlined,
                    title: 'System VPN Settings',
                    subtitle: 'Always-on VPN & block-without-VPN',
                    onTap: () =>
                        VpnController.instance.openSystemVpnSettings(),
                  ),
                  _sectionLabel('Support'),
                  MenuRow(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const InfoPage(
                            title: 'Help & Support', body: _helpText))),
                  ),
                  MenuRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const InfoPage(
                            title: 'Privacy Policy', body: _privacyText))),
                  ),
                  MenuRow(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const InfoPage(
                            title: 'Terms of Service', body: _termsText))),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text('SecureNet 1.1.0 · Live servers by VPN Gate',
                        style:
                            TextStyle(color: Brand.textDim, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        child: Text(t,
            style: const TextStyle(
                color: Brand.textDim,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
      );

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
          style: const TextStyle(color: Brand.text, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Brand.textDim, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: Brand.blue,
        inactiveTrackColor: Brand.border,
      ),
    );
  }

  void _infoDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Brand.card,
        title: Text(title, style: const TextStyle(color: Brand.text)),
        content: Text(body,
            style: const TextStyle(color: Brand.textDim, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Brand.blue)),
          ),
        ],
      ),
    );
  }
}

const _helpText = '''
Why is a server slow or unreachable?
The servers are public relays run by volunteers around the world (the VPN Gate project). Speed and availability change minute by minute. Tap Refresh on the Locations screen for the newest list. SecureNet shows only the single best server for each country.

The connection dropped by itself
SecureNet reconnects automatically whenever the tunnel is interrupted, and keeps retrying until it succeeds — you do not need to do anything. If drops keep happening, open Settings → Stable Connection and allow SecureNet to run without battery limits: many phones aggressively stop VPN apps in the background to save power. For the strongest protection, also enable "Always-on VPN" in Settings → System VPN Settings.

The app says "VPN permission was refused"
Android asks once for permission to create the VPN tunnel. Accept the system dialog, or the connection cannot start.

Which server should I pick?
Each country shows its best server, ranked by a quality score that blends line speed, ping and reliability. Low ping = most responsive; high listed capacity (Mbps) = better for video.
''';

const _privacyText = '''
SecureNet is a client app. It does not have user accounts and it does not collect, store, or sell your browsing activity.

Your connection is routed through public relay servers operated by volunteers of the VPN Gate academic project (University of Tsukuba). SecureNet does not operate those servers. VPN Gate's own policy keeps connection logs on the relay servers for about two weeks for abuse prevention; the operator shown on each server is responsible for that server.

The app stores only your settings and your own usage statistics (time connected, data transferred, countries used) on this device. The server list is fetched from the public VPN Gate API. No analytics or advertising SDKs are included in this build.
''';

const _termsText = '''
SecureNet is provided as-is, free of charge, for personal use. VPN servers are public community relays; availability, speed and uptime are not guaranteed.

You are responsible for using this app in line with the laws and regulations that apply where you are. Do not use the service for abusive, fraudulent or illegal activity; relay operators may block abusive traffic at any time.

The developers may update or discontinue the app at any time.
''';

/// Simple scrollable text page (privacy, terms, help).
class InfoPage extends StatelessWidget {
  final String title;
  final String body;
  const InfoPage({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg0,
      appBar: _pageBar(context, title),
      body: Container(
        decoration: Brand.screenGradient,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Text(
            body.trim(),
            style: const TextStyle(
                color: Color(0xFF5B4632), fontSize: 14.5, height: 1.55),
          ),
        ),
      ),
    );
  }
}

PreferredSizeWidget _pageBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back, color: Brand.text),
    ),
    title: Text(title,
        style: const TextStyle(
            color: Brand.text, fontSize: 18, fontWeight: FontWeight.w700)),
    centerTitle: false,
  );
}
