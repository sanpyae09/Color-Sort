import 'package:flutter/material.dart';

import 'data.dart';
import 'store.dart';
import 'vpn.dart';
import 'widgets.dart';

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
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  _sectionLabel('Account'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PremiumPage())),
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: Brand.cardBox(color: Brand.cardSoft),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          child: const Row(
                            children: [
                              Icon(Icons.workspace_premium,
                                  color: Brand.gold, size: 26),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Premium Plan',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        'Free during the test period',
                                        style: TextStyle(
                                            color: Brand.textDim,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: Brand.textDim),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  MenuRow(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    subtitle: 'Your local usage statistics',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfilePage())),
                  ),
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
                        'Block traffic and auto-reconnect if the tunnel drops',
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
                    child: Text('SecureNet 1.0.0 · Live servers by VPN Gate',
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
          style: const TextStyle(color: Colors.white, fontSize: 15)),
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
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body,
            style: const TextStyle(color: Brand.textDim, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('OK', style: TextStyle(color: Brand.cyan)),
          ),
        ],
      ),
    );
  }
}

const _helpText = '''
Why is a server slow or unreachable?
The servers are public relays run by volunteers around the world (the VPN Gate project). Speed and availability change minute by minute. Tap Refresh on the Locations screen for the newest list, and prefer low-ping servers near you.

The app says "VPN permission was refused"
Android asks once for permission to create the VPN tunnel. Accept the system dialog, or the connection cannot start. You can also check Settings → System VPN Settings.

What does the Kill Switch do?
If the tunnel drops unexpectedly, SecureNet blocks the screen with a reconnecting notice and retries your server automatically (up to 5 times). For the strongest protection, also enable "Always-on VPN" and "Block connections without VPN" in the system VPN settings.

Which server should I pick?
Lowest ping = most responsive. High "listed capacity" (Mbps) = better for video. Servers are sorted by a community score by default.
''';

const _privacyText = '''
SecureNet is a client app. It does not have user accounts and it does not collect, store, or sell your browsing activity.

Your connection is routed through public relay servers operated by volunteers of the VPN Gate academic project (University of Tsukuba). SecureNet does not operate those servers. VPN Gate's own policy keeps connection logs on the relay servers for about two weeks for abuse prevention; the operator shown on each server is responsible for that server.

The app stores only your settings and your own usage statistics (time connected, data transferred, countries used) on this device. The server list is fetched from the public VPN Gate API. No analytics or advertising SDKs are included in this build.
''';

const _termsText = '''
SecureNet is provided as-is, free of charge, for personal use. VPN servers are public community relays; availability, speed and uptime are not guaranteed.

You are responsible for using this app in line with the laws and regulations that apply where you are. Do not use the service for abusive, fraudulent or illegal activity; relay operators may block abusive traffic at any time.

The developers may update or discontinue the app at any time. Premium features shown in the app are not yet available for purchase.
''';

/// Screen 10 — Premium upgrade (visual only; no payments in this build).
class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg0,
      appBar: _pageBar(context, ''),
      body: Container(
        decoration: Brand.screenGradient,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
          children: [
            const Icon(Icons.workspace_premium,
                color: Brand.gold, size: 52),
            const SizedBox(height: 10),
            const Center(
              child: Text('Go Premium',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Unlock the full potential of SecureNet\nwith premium features.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.textDim, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            ...const [
              'Unlimited Bandwidth',
              'Access to 100+ Countries',
              'Ad-Free Experience',
              'Multi-Device Support',
              '24/7 Priority Support',
            ].map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Brand.green, size: 20),
                      const SizedBox(width: 10),
                      Text(f,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _planCard('Monthly', '\$4.99', '/month', false)),
                const SizedBox(width: 12),
                Expanded(child: _planCard('Yearly', '\$39.99', '/year', true)),
              ],
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Upgrade Now',
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Brand.card,
                  title: const Text('Coming soon',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'Premium is not on sale yet. Every feature in this '
                    'test build is completely free — enjoy!',
                    style: TextStyle(color: Brand.textDim, height: 1.45),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK',
                          style: TextStyle(color: Brand.cyan)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(String name, String price, String per, bool featured) {
    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: featured ? Brand.blue : Brand.border,
            width: featured ? 2 : 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          if (featured)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Brand.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Save 33%',
                  style: TextStyle(color: Colors.white, fontSize: 10.5)),
            ),
          const SizedBox(height: 6),
          Text(name,
              style: const TextStyle(color: Brand.textDim, fontSize: 13)),
          const SizedBox(height: 4),
          Text(price,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(per,
              style: const TextStyle(color: Brand.textDim, fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// Screen 11 — Streaming Mode info + one-tap connect to a low-ping server.
class StreamingPage extends StatelessWidget {
  const StreamingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg0,
      appBar: _pageBar(context, 'Streaming Mode'),
      body: Container(
        decoration: Brand.screenGradient,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          children: [
            Container(
              height: 170,
              decoration: Brand.cardBox(color: Brand.cardSoft),
              child: const Center(
                child: Icon(Icons.live_tv, color: Brand.cyan, size: 76),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Access your favorite content\nfrom anywhere',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.3),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Start Streaming picks the lowest-ping live server, '
                'which gives the smoothest playback.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.textDim, height: 1.45),
              ),
            ),
            const SizedBox(height: 18),
            ...const [
              'Optimized for Streaming',
              'HD Video Support',
              'Fast & Stable Connection',
            ].map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Brand.green, size: 20),
                      const SizedBox(width: 10),
                      Text(f,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Start Streaming',
              icon: Icons.play_arrow,
              onTap: () async {
                final repo = ServerRepository.instance;
                if (repo.servers.isEmpty) await repo.refresh();
                final picks = repo.streamingPicks;
                final target =
                    picks.isNotEmpty ? picks.first : repo.fastest;
                if (target != null) {
                  VpnController.instance.connectTo(target);
                }
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text('Learn More',
                  style: TextStyle(color: Brand.cyan, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 12 — Profile with real local usage statistics.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final totalData = store.totalBytesIn + store.totalBytesOut;
    return Scaffold(
      backgroundColor: Brand.bg0,
      appBar: _pageBar(context, 'Profile'),
      body: Container(
        decoration: Brand.screenGradient,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          children: [
            Center(
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset('assets/images/app_icon.png',
                        width: 84, height: 84, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  const Text('Guest User',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  const Text('No account needed — guest mode',
                      style: TextStyle(color: Brand.textDim, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PremiumPage())),
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  decoration: Brand.cardBox(color: Brand.cardSoft),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  child: const Row(
                    children: [
                      Icon(Icons.workspace_premium,
                          color: Brand.gold, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Free Member',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Text('All test features unlocked',
                                style: TextStyle(
                                    color: Brand.textDim, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Brand.textDim),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _profileStat('${store.daysConnected}', 'Days\nConnected'),
                _profileStat(
                    '${store.countriesUsed.length}', 'Countries\nUsed'),
                _profileStat(formatBytes(totalData), 'Data\nUsed'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: Brand.cardBox(),
              child: Column(
                children: [
                  MenuRow(
                    icon: Icons.card_membership,
                    title: 'My Subscriptions',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PremiumPage())),
                  ),
                  MenuRow(
                    icon: Icons.history,
                    title: 'Usage History',
                    subtitle:
                        '${store.sessionCount} sessions · ${_fmtDuration(store.totalSeconds)} total',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const InfoPage(
                                title: 'Usage History',
                                body: ''))),
                  ),
                  MenuRow(
                    icon: Icons.devices_outlined,
                    title: 'Device Management',
                    subtitle: 'This device · Android',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const InfoPage(
                                title: 'Device Management',
                                body:
                                    'SecureNet is running on this Android device only. There is no account and no other device is linked.\n\nYour settings and usage statistics never leave this phone.'))),
                  ),
                  MenuRow(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const InfoPage(
                                title: 'Help & Support', body: _helpText))),
                  ),
                  MenuRow(
                    icon: Icons.logout,
                    title: 'Log Out',
                    trailing: const SizedBox.shrink(),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Brand.card,
                        title: const Text('Guest mode',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'You are using SecureNet as a guest — there is '
                          'no account to log out of. Your settings stay '
                          'on this device.',
                          style:
                              TextStyle(color: Brand.textDim, height: 1.45),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK',
                                style: TextStyle(color: Brand.cyan)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDuration(int secs) {
    if (secs < 3600) return '${secs ~/ 60} min';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  Widget _profileStat(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: Brand.cardBox(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Brand.textDim, fontSize: 11, height: 1.25)),
          ],
        ),
      ),
    );
  }
}

/// Simple scrollable text page (privacy, terms, help, device info).
class InfoPage extends StatelessWidget {
  final String title;
  final String body;
  const InfoPage({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final text = title == 'Usage History'
        ? 'Sessions: ${store.sessionCount}\n'
            'Total time connected: ${ProfilePage._fmtDuration(store.totalSeconds)}\n'
            'Downloaded: ${formatBytes(store.totalBytesIn)}\n'
            'Uploaded: ${formatBytes(store.totalBytesOut)}\n'
            'Countries used: ${store.countriesUsed.isEmpty ? '—' : store.countriesUsed.join(', ')}\n'
            'Days connected: ${store.daysConnected}'
        : body;
    return Scaffold(
      backgroundColor: Brand.bg0,
      appBar: _pageBar(context, title),
      body: Container(
        decoration: Brand.screenGradient,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Text(
            text.trim(),
            style: const TextStyle(
                color: Color(0xFFC9D6F2), fontSize: 14.5, height: 1.55),
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
      icon: const Icon(Icons.arrow_back, color: Colors.white),
    ),
    title: Text(title,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    centerTitle: false,
  );
}
