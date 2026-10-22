import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ads.dart';
import 'data.dart';
import 'result.dart';
import 'store.dart';
import 'widgets.dart';

class QuizScreen extends StatefulWidget {
  final List<Question> questions;
  final String title;
  final bool isDaily;
  final String? category;
  const QuizScreen({super.key, required this.questions, required this.title, required this.isDaily, this.category});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  static const int secondsPerQuestion = 20;

  late final AnimationController _timer = AnimationController(vsync: this, duration: const Duration(seconds: secondsPerQuestion));
  int _index = 0;
  int? _selected;
  bool _answered = false;
  bool _timedOut = false;
  int _correctCount = 0;
  int _secondsLeft = secondsPerQuestion;
  int _shakeTrigger = 0;
  bool _fiftyUsed = false;
  bool _skipUsed = false;
  bool _hintUsed = false;
  bool _hintShown = false;
  Set<int> _hidden = {};
  late final DateTime _roundStart = DateTime.now();

  Question get _q => widget.questions[_index];
  int get _total => widget.questions.length;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onTick);
    _timer.forward();
  }

  @override
  void dispose() {
    _timer.removeListener(_onTick);
    _timer.dispose();
    super.dispose();
  }

  void _onTick() {
    final left = (secondsPerQuestion * (1 - _timer.value)).ceil();
    if (left != _secondsLeft && mounted) {
      setState(() => _secondsLeft = left);
    }
    if (_timer.isCompleted && !_answered) {
      _onTimeout();
    }
  }

  void _soundClick() {
    if (Store.instance.soundOn) SystemSound.play(SystemSoundType.click);
  }

  void _select(int i) {
    if (_answered || _hidden.contains(i)) return;
    _timer.stop();
    _soundClick();
    final correct = i == _q.correct - 1;
    Store.instance.recordAnswer(_q.id, correct);
    setState(() {
      _selected = i;
      _answered = true;
      if (correct) {
        _correctCount++;
      } else {
        _shakeTrigger++;
      }
    });
  }

  void _onTimeout() {
    if (_answered) return;
    Store.instance.recordAnswer(_q.id, false);
    setState(() {
      _answered = true;
      _timedOut = true;
    });
  }

  void _useFifty() {
    if (_answered || _fiftyUsed) return;
    _soundClick();
    final wrong = [0, 1, 2, 3].where((i) => i != _q.correct - 1).toList()..shuffle();
    setState(() {
      _fiftyUsed = true;
      _hidden = wrong.take(2).toSet();
    });
  }

  void _useSkip() {
    if (_answered || _skipUsed) return;
    _soundClick();
    Store.instance.markSeen(_q.id);
    setState(() => _skipUsed = true);
    _advance();
  }

  Future<void> _useHint() async {
    if (_answered || _hintUsed) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Brand.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(color: Brand.gold.withValues(alpha: 0.16), shape: BoxShape.circle),
                child: const Icon(Icons.card_giftcard_rounded, color: Brand.gold, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Keep Going!', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Watch a short video to get a hint for this question.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              PressScale(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(14)),
                  child: const Text('Watch Ad & Get Hint', style: TextStyle(color: Brand.navy, fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Maybe Later', style: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final shown = Ads.showRewarded(onReward: () {
      if (!mounted) return;
      setState(() {
        _hintUsed = true;
        _hintShown = true;
      });
    });
    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test ad is still loading — try again in a few seconds.')));
    }
  }

  void _advance() {
    if (_index >= _total - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
      _timedOut = false;
      _hidden = {};
      _hintShown = false;
      _secondsLeft = secondsPerQuestion;
    });
    _timer.reset();
    _timer.forward();
  }

  Future<void> _finish() async {
    final elapsed = DateTime.now().difference(_roundStart).inSeconds;
    final coinsEarned = _correctCount * 10;
    final xpEarned = _correctCount * 10 + 20;
    final store = Store.instance;
    await store.recordRound(correctCount: _correctCount, coinsEarned: coinsEarned, xpEarned: xpEarned, isDaily: widget.isDaily);
    if (!mounted) return;
    final lastFact = widget.questions.last.fact;
    Navigator.of(context).pushReplacement(
      FadeSlideRoute(
        builder: (_) => ResultScreen(
          correct: _correctCount,
          total: _total,
          seconds: elapsed,
          coinsEarned: coinsEarned,
          xpEarned: xpEarned,
          isDaily: widget.isDaily,
          category: widget.category,
          title: widget.title,
          fact: lastFact,
        ),
      ),
    );
    Ads.maybeShowInterstitial(store.roundsPlayed);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Scaffold(
      backgroundColor: Brand.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: progress count + timer readout
              Row(
                children: [
                  Text('${_index + 1} / $_total', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 5),
                  Text('00:${_secondsLeft.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              // Round progress (animated)
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: (_index + (_answered ? 1 : 0)) / _total),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    valueColor: const AlwaysStoppedAnimation<Color>(Brand.green),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Countdown bar (continuous, shifts red under 5s)
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: AnimatedBuilder(
                  animation: _timer,
                  builder: (context, _) {
                    final remain = 1 - _timer.value;
                    final secs = remain * secondsPerQuestion;
                    final color = _answered
                        ? Colors.white24
                        : secs <= 5
                            ? Brand.red
                            : secs <= 10
                                ? Brand.gold
                                : Brand.blue;
                    return LinearProgressIndicator(
                      value: _answered ? remain : remain,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.14, 0), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(_index),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.category == 'Space & Astronomy')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset('assets/images/earth.jpg', height: 148, width: double.infinity, fit: BoxFit.cover),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: Brand.navyCard, borderRadius: BorderRadius.circular(99)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(categoryInfo(q.cat).icon, color: categoryInfo(q.cat).color, size: 16),
                                  const SizedBox(width: 7),
                                  Text(q.cat, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  Text('  •  ${q.diff[0].toUpperCase()}${q.diff.substring(1)}', style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                        Text(q.q, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700, height: 1.3)),
                        const SizedBox(height: 20),
                        ...List.generate(4, (i) => _answerButton(i)),
                        if (_hintShown && !_answered)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Brand.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Brand.gold.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: Brand.gold, size: 19),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Hint: ${q.fact}', style: const TextStyle(color: Color(0xFFFFE9A8), fontSize: 13.5, height: 1.4))),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom area: lifelines OR fact + next
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim), child: child),
                ),
                child: _answered ? _factPanel() : _lifelineRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerButton(int i) {
    final q = _q;
    final isCorrect = i == q.correct - 1;
    final isSelected = i == _selected;
    Color bg = Brand.navyCard;
    Color border = Colors.white.withValues(alpha: 0.10);
    double opacity = 1;
    if (_answered) {
      if (isCorrect) {
        bg = Brand.green;
        border = Brand.green;
      } else if (isSelected) {
        bg = Brand.red;
        border = Brand.red;
      } else {
        opacity = 0.5;
      }
    }
    final button = Opacity(
      opacity: _hidden.contains(i) ? 0 : opacity,
      child: AnimatedScale(
        scale: _answered && isCorrect ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 1.4)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _answered || _hidden.contains(i) ? null : () => _select(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle),
                      child: Text('ABCD'[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ),
                    const SizedBox(width: 13),
                    Expanded(child: Text(q.a[i], style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600))),
                    if (_answered && isCorrect) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 21),
                    if (_answered && isSelected && !isCorrect) const Icon(Icons.cancel_rounded, color: Colors.white, size: 21),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (_answered && isSelected && !isCorrect) {
      return ShakeOn(trigger: _shakeTrigger, child: button);
    }
    return button;
  }

  Widget _lifelineRow() {
    return Row(
      key: const ValueKey('lifelines'),
      children: [
        _lifelineChip(Icons.percent_rounded, '50:50', _fiftyUsed ? null : _useFifty, _fiftyUsed),
        const SizedBox(width: 10),
        _lifelineChip(Icons.lightbulb_rounded, 'Hint', _hintUsed ? null : _useHint, _hintUsed),
        const SizedBox(width: 10),
        _lifelineChip(Icons.skip_next_rounded, 'Skip', _skipUsed ? null : _useSkip, _skipUsed),
      ],
    );
  }

  Widget _lifelineChip(IconData icon, String label, VoidCallback? onTap, bool used) {
    return Expanded(
      child: Opacity(
        opacity: used ? 0.38 : 1,
        child: PressScale(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Brand.navyCard, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: 0.10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Brand.gold, size: 18),
                const SizedBox(width: 7),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _factPanel() {
    final wasCorrect = _selected != null && _selected == _q.correct - 1;
    return Column(
      key: const ValueKey('fact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Brand.navyCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_timedOut ? Icons.timer_off_rounded : wasCorrect ? Icons.celebration_rounded : Icons.lightbulb_rounded, color: Brand.gold, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _timedOut ? 'Time\'s up! The answer is ${_q.a[_q.correct - 1]}. ${_q.fact}' : _q.fact,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PressScale(
          onTap: _advance,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Brand.blue, borderRadius: BorderRadius.circular(16)),
            child: Text(_index >= _total - 1 ? 'See Results' : 'Next Question', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
