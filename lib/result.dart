import 'dart:math';
import 'package:flutter/material.dart';
import 'ads.dart';
import 'data.dart';
import 'quiz.dart';
import 'store.dart';
import 'widgets.dart';

class ResultScreen extends StatefulWidget {
  final int correct;
  final int total;
  final int seconds;
  final int coinsEarned;
  final int xpEarned;
  final bool isDaily;
  final String? category;
  final String title;
  final String fact;
  const ResultScreen({
    super.key,
    required this.correct,
    required this.total,
    required this.seconds,
    required this.coinsEarned,
    required this.xpEarned,
    required this.isDaily,
    required this.category,
    required this.title,
    required this.fact,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  late final List<_Particle> _particles = _makeParticles();
  bool _doubled = false;

  double get _accuracy => widget.total == 0 ? 0 : widget.correct / widget.total;

  List<_Particle> _makeParticles() {
    final rng = Random(20261022);
    const colors = [Brand.blue, Brand.gold, Brand.green, Color(0xFFEC4899), Color(0xFF7C3AED)];
    return List.generate(90, (i) {
      return _Particle(
        x: rng.nextDouble(),
        size: 5 + rng.nextDouble() * 7,
        color: colors[i % colors.length],
        speed: 0.65 + rng.nextDouble() * 0.6,
        drift: (rng.nextDouble() - 0.5) * 0.09,
        spin: rng.nextDouble() * 6.28,
        circle: rng.nextBool(),
        delay: rng.nextDouble() * 0.22,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _confetti.forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _headline {
    if (_accuracy >= 0.8) return 'Well Done!';
    if (_accuracy >= 0.5) return 'Good Job!';
    return 'Keep Going!';
  }

  String get _timeText {
    final m = widget.seconds ~/ 60;
    final s = widget.seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _playAgain() {
    final store = Store.instance;
    final bank = QuestionBank.instance;
    List<Question> qs;
    if (widget.isDaily) {
      qs = bank.daily(DateTime.now());
    } else if (widget.category != null) {
      qs = bank.forCategory(widget.category!, 10, store.seenIds);
    } else {
      qs = bank.mixed(10, store.seenIds);
    }
    Navigator.of(context).pushReplacement(
      FadeSlideRoute(builder: (_) => QuizScreen(questions: qs, title: widget.title, isDaily: widget.isDaily, category: widget.category)),
    );
  }

  void _next() {
    // From a category round: jump to the next category. Otherwise: home.
    if (widget.category != null && !widget.isDaily) {
      final idx = kCategories.indexWhere((c) => c.name == widget.category);
      final nextCat = kCategories[(idx + 1) % kCategories.length];
      final qs = QuestionBank.instance.forCategory(nextCat.name, 10, Store.instance.seenIds);
      Navigator.of(context).pushReplacement(
        FadeSlideRoute(builder: (_) => QuizScreen(questions: qs, title: nextCat.name, isDaily: false, category: nextCat.name)),
      );
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.cream,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      PressScale(
                        onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.home_rounded, color: Brand.ink, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Brand.inkSoft)),
                      const Spacer(),
                      const SizedBox(width: 36),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Celebrating owl: elastic scale-in, then gentle bobbing.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.elasticOut,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Bobbing(child: Image.asset('assets/images/owl_mascot.png', width: 128, height: 128)),
                  ),
                  const SizedBox(height: 6),
                  FadeSlideIn(
                    delayMs: 150,
                    child: Column(
                      children: [
                        Text(_headline, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: Color(0xFF0E7A3D))),
                        const SizedBox(height: 4),
                        Text('You got ${widget.correct} out of ${widget.total} correct!', style: const TextStyle(fontSize: 15, color: Brand.inkSoft, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    delayMs: 250,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 5))]),
                      child: Row(
                        children: [
                          // Animated accuracy ring
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: _accuracy),
                            duration: const Duration(milliseconds: 950),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => SizedBox(
                              width: 96,
                              height: 96,
                              child: CustomPaint(
                                painter: _RingPainter(v),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Brand.ink)),
                                      const Text('Accuracy', style: TextStyle(fontSize: 10.5, color: Brand.inkSoft)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                _statRow(Icons.check_circle_rounded, Brand.green, '${widget.correct}', 'Correct'),
                                const SizedBox(height: 10),
                                _statRow(Icons.cancel_rounded, Brand.red, '${widget.total - widget.correct}', 'Wrong'),
                                const SizedBox(height: 10),
                                _statRow(Icons.schedule_rounded, Brand.inkSoft, _timeText, 'Time'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 350,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on, color: Color(0xFFF5A623), size: 21),
                          const SizedBox(width: 7),
                          CountUp(value: widget.coinsEarned * (_doubled ? 2 : 1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.ink)),
                          const Text(' coins earned', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Brand.ink)),
                          const Text('   •   ', style: TextStyle(color: Brand.inkSoft)),
                          const Icon(Icons.bolt_rounded, color: Brand.blue, size: 19),
                          const SizedBox(width: 4),
                          CountUp(value: widget.xpEarned, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.ink)),
                          const Text(' XP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Brand.ink)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 430,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFFFF6DE), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF3DFA6))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_rounded, color: Color(0xFFF5A623), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fun Fact', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Brand.ink)),
                                const SizedBox(height: 3),
                                Text(widget.fact, style: const TextStyle(fontSize: 13.5, height: 1.45, color: Brand.ink)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    delayMs: 500,
                    child: Column(
                      children: [
                        if (widget.coinsEarned > 0 && !_doubled)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PressScale(
                              onTap: () {
                                final shown = Ads.showRewarded(onReward: () {
                                  Store.instance.addCoins(widget.coinsEarned);
                                  if (mounted) {
                                    setState(() => _doubled = true);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coins doubled! +${widget.coinsEarned} bonus coins')));
                                  }
                                });
                                if (!shown) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test ad is still loading — try again in a few seconds.')));
                                }
                              },
                              child: Container(
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(16)),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.play_circle_fill_rounded, color: Brand.navy, size: 22),
                                    SizedBox(width: 8),
                                    Text('Double Coins — Watch Ad', style: TextStyle(color: Brand.navy, fontSize: 15.5, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_doubled)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Brand.green, size: 19),
                                SizedBox(width: 6),
                                Text('Coins doubled!', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0E7A3D))),
                              ],
                            ),
                          ),
                        PressScale(
                          onTap: _next,
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Brand.blue, borderRadius: BorderRadius.circular(16)),
                            child: Text(widget.category != null && !widget.isDaily ? 'Next Category' : 'Done', style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: PressScale(
                                onTap: _playAgain,
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD8E2F2), width: 1.4)),
                                  child: const Text('Play Again', style: TextStyle(color: Brand.blue, fontSize: 15, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PressScale(
                                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD8E2F2), width: 1.4)),
                                  child: const Text('Home', style: TextStyle(color: Brand.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Confetti burst overlay (custom painter, runs once on open)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_confetti.value, _particles)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, Color color, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.ink)),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 13.5, color: Brand.inkSoft)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    final bg = Paint()
      ..color = const Color(0xFFE8EEF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawCircle(center, radius, bg);
    if (progress > 0) {
      final fg = Paint()
        ..color = Brand.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, 2 * pi * progress, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}

class _Particle {
  final double x;
  final double size;
  final Color color;
  final double speed;
  final double drift;
  final double spin;
  final bool circle;
  final double delay;
  const _Particle({required this.x, required this.size, required this.color, required this.speed, required this.drift, required this.spin, required this.circle, required this.delay});
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;
  _ConfettiPainter(this.t, this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final y = -24 + (size.height + 48) * local * p.speed;
      final x = (p.x + p.drift * local) * size.width;
      final opacity = local > 0.82 ? (1 - local) / 0.18 : 1.0;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local * 2);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.62), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
