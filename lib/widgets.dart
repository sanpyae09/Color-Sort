import 'dart:math';
import 'package:flutter/material.dart';

/// Brand palette (from the approved design reference).
class Brand {
  static const blue = Color(0xFF2563EB);
  static const blueDark = Color(0xFF1D4ED8);
  static const navy = Color(0xFF0B1B3A);
  static const navyCard = Color(0xFF14264E);
  static const gold = Color(0xFFFFC531);
  static const cream = Color(0xFFFFF9EC);
  static const bg = Color(0xFFF6F9FF);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const ink = Color(0xFF16233F);
  static const inkSoft = Color(0xFF5B6B8C);
}

/// Fade + slide page route used for all screen transitions.
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  FadeSlideRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Fades + slides a child in on first build, with an optional stagger delay.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    if (widget.delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Press-down scale feedback wrapper for buttons/cards.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const PressScale({super.key, required this.child, this.onTap});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Gentle idle bobbing (mascot idle animation).
class Bobbing extends StatefulWidget {
  final Widget child;
  final double distance;
  const Bobbing({super.key, required this.child, this.distance = 6});

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(offset: Offset(0, -widget.distance * t), child: child);
      },
      child: widget.child,
    );
  }
}

/// Animated integer that counts from its previous value to the new one.
class CountUp extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  const CountUp({super.key, required this.value, this.style, this.duration = const Duration(milliseconds: 600)});

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  int _from = 0;

  @override
  void didUpdateWidget(covariant CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _from = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from.toDouble(), end: widget.value.toDouble()),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: widget.style),
    );
  }
}

/// Horizontal shake animation, replays whenever [trigger] changes.
class ShakeOn extends StatefulWidget {
  final Widget child;
  final int trigger;
  const ShakeOn({super.key, required this.child, required this.trigger});

  @override
  State<ShakeOn> createState() => _ShakeOnState();
}

class _ShakeOnState extends State<ShakeOn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didUpdateWidget(covariant ShakeOn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final dx = t == 0 || t == 1 ? 0.0 : sin(t * pi * 4) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
