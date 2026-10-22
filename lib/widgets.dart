import 'package:flutter/material.dart';

import 'data.dart';
import 'vpn.dart';

/// SecureNet brand kit — deep navy + electric blue, per the design sheet.
class Brand {
  static const bg0 = Color(0xFF030A22);
  static const bg1 = Color(0xFF0A1C40);
  static const card = Color(0xFF0C2150);
  static const cardSoft = Color(0xFF102A5E);
  static const border = Color(0xFF1D3A6E);
  static const blue = Color(0xFF2E7CF6);
  static const cyan = Color(0xFF38BDF8);
  static const green = Color(0xFF2EEA8C);
  static const amber = Color(0xFFFFB84D);
  static const red = Color(0xFFFF5C5C);
  static const textDim = Color(0xFF8CA3C7);
  static const gold = Color(0xFFFFC93C);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1E6FEB), Color(0xFF38BDF8)],
  );

  static BoxDecoration get screenGradient => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg1, bg0],
        ),
      );

  static BoxDecoration cardBox({Color? color}) => BoxDecoration(
        color: color ?? card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      );
}

class FlagCircle extends StatelessWidget {
  final VpnServer server;
  final double size;
  const FlagCircle({super.key, required this.server, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        server.flagAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Brand.cardSoft,
          alignment: Alignment.center,
          child: Text(
            server.countryShort,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 4-bar signal indicator graded by ping.
class SignalBars extends StatelessWidget {
  final int ping;
  const SignalBars({super.key, required this.ping});

  @override
  Widget build(BuildContext context) {
    int bars;
    Color color;
    if (ping <= 0) {
      bars = 0;
      color = Brand.textDim;
    } else if (ping <= 60) {
      bars = 4;
      color = Brand.green;
    } else if (ping <= 120) {
      bars = 3;
      color = Brand.green;
    } else if (ping <= 200) {
      bars = 2;
      color = Brand.amber;
    } else {
      bars = 1;
      color = Brand.red;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final h = 5.0 + i * 3.0;
        return Container(
          width: 3.5,
          height: h,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: i < bars ? color : Brand.border,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Brand.cardBox(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(label,
                  style:
                      const TextStyle(color: Brand.textDim, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              Text(unit,
                  style:
                      const TextStyle(color: Brand.textDim, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            gradient: Brand.primaryGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Brand.blue.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big glowing power button from the design sheet (screens 3/5/6).
class ConnectButton extends StatefulWidget {
  final VpnPhase phase;
  final VoidCallback onTap;
  const ConnectButton({super.key, required this.phase, required this.onTap});

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.phase == VpnPhase.connecting ||
        widget.phase == VpnPhase.reconnecting) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final Color ring = switch (phase) {
      VpnPhase.connected => Brand.green,
      VpnPhase.reconnecting => Brand.amber,
      VpnPhase.error || VpnPhase.denied => Brand.red,
      _ => Brand.blue,
    };
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        final scale = 1.0 + t * 0.03;
        return GestureDetector(
          onTap: widget.onTap,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 208,
              height: 208,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Brand.cardSoft,
                    Brand.bg0,
                  ],
                ),
                border: Border.all(color: ring, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: ring.withValues(alpha: 0.55 + t * 0.25),
                    blurRadius: 42 + t * 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.power_settings_new,
                size: 74,
                color: phase == VpnPhase.connected ? Brand.green : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppHeader extends StatelessWidget {
  final VoidCallback? onCrown;
  final VoidCallback? onProfile;
  const AppHeader({super.key, this.onCrown, this.onProfile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/images/app_icon.png',
                width: 30, height: 30),
          ),
          const SizedBox(width: 9),
          const Text('SecureNet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            onPressed: onCrown,
            icon: const Icon(Icons.workspace_premium,
                color: Brand.gold, size: 24),
          ),
          IconButton(
            onPressed: onProfile,
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
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
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: const TextStyle(color: Brand.textDim, fontSize: 12)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: Brand.textDim, size: 20),
    );
  }
}
