import 'package:flutter/material.dart';

import 'data.dart';
import 'vpn.dart';

/// SecureNet brand kit — milk-cream + orange (build 2, user-chosen palette).
class Brand {
  static const bg0 = Color(0xFFFFFBF2); // milk cream
  static const bg1 = Color(0xFFFFF1DC); // warm cream (top)
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFFFEAD1); // soft peach
  static const border = Color(0xFFF1DCBB);
  static const blue = Color(0xFFF97316); // primary orange
  static const cyan = Color(0xFFFB8C1A); // accent orange
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFE5484D);
  static const text = Color(0xFF33241A); // dark cocoa
  static const textDim = Color(0xFF9A7B5F);
  static const gold = Color(0xFFF59E0B);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFF97316), Color(0xFFFB923C)],
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
              color: Brand.text,
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
                      color: Brand.text,
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

/// Compact primary action button (orange gradient).
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
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: Brand.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Brand.blue.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 19),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big power button (home screen). White disc, colored ring by phase.
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
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFFFE9D2),
                  ],
                ),
                border: Border.all(color: ring, width: 5),
                boxShadow: [
                  BoxShadow(
                    color: ring.withValues(alpha: 0.35 + t * 0.2),
                    blurRadius: 34 + t * 14,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                Icons.power_settings_new,
                size: 70,
                color: ring,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slim app header: logo + name only (build 2 removed the extra buttons).
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
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
                  color: Brand.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
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
          style: const TextStyle(color: Brand.text, fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: const TextStyle(color: Brand.textDim, fontSize: 12)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: Brand.textDim, size: 20),
    );
  }
}
