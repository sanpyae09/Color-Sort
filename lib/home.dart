import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads.dart';
import 'data.dart';
import 'quiz.dart';
import 'store.dart';
import 'widgets.dart';

void startQuiz(BuildContext context, {required List<Question> questions, required String title, required bool isDaily, String? category}) {
  Navigator.of(context).push(
    FadeSlideRoute(
      builder: (_) => QuizScreen(questions: questions, title: title, isDaily: isDaily, category: category),
    ),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  HomeTab(onSeeAll: () => setState(() => _tab = 1)),
                  const CategoriesTab(),
                  const StatsTab(),
                  const ProfileTab(),
                ],
              ),
            ),
            if (_tab == 0) const _BannerSlot(),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _NavBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.home_rounded, 'Home'),
      (Icons.grid_view_rounded, 'Categories'),
      (Icons.bar_chart_rounded, 'Stats'),
      (Icons.person_rounded, 'Profile'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == index;
              return Expanded(
                child: PressScale(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        width: active ? 26 : 0,
                        height: 3,
                        decoration: BoxDecoration(color: Brand.blue, borderRadius: BorderRadius.circular(99)),
                      ),
                      const SizedBox(height: 5),
                      AnimatedScale(
                        scale: active ? 1.12 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(items[i].$1, color: active ? Brand.blue : Brand.inkSoft, size: 25),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Brand.blue : Brand.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot();

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!Ads.enabled) return;
    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: Ads.bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      width: double.infinity,
      height: 56,
      child: SizedBox(width: _ad!.size.width.toDouble(), height: _ad!.size.height.toDouble(), child: AdWidget(ad: _ad!)),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME TAB
// ---------------------------------------------------------------------------

class HomeTab extends StatelessWidget {
  final VoidCallback onSeeAll;
  const HomeTab({super.key, required this.onSeeAll});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final bank = QuestionBank.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final dailyDone = store.dailyDoneDate == Store.dateStr(DateTime.now());
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: logo + coins + avatar
              FadeSlideIn(
                child: Row(
                  children: [
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Quiz', style: TextStyle(color: Brand.navy)),
                        TextSpan(text: 'Nova', style: TextStyle(color: Brand.blue)),
                      ]),
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(99)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: Color(0xFFF5A623), size: 19),
                          const SizedBox(width: 5),
                          CountUp(value: store.coins, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Brand.blue, width: 2),
                        image: const DecorationImage(image: AssetImage('assets/images/owl_mascot.png'), fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Greeting + bobbing owl
              FadeSlideIn(
                delayMs: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Brand.ink)),
                          const Text('Explorer!', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Brand.ink)),
                          const SizedBox(height: 4),
                          const Text('Ready for a new challenge?', style: TextStyle(fontSize: 13.5, color: Brand.inkSoft)),
                        ],
                      ),
                    ),
                    Bobbing(child: Image.asset('assets/images/owl_mascot.png', width: 74, height: 74)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Pulsing PLAY button (quick mixed round)
              FadeSlideIn(delayMs: 120, child: _PulsePlay(onTap: () {
                startQuiz(context, questions: bank.mixed(10, store.seenIds), title: 'Quick Play', isDaily: false);
              })),
              const SizedBox(height: 16),
              // Daily challenge card
              FadeSlideIn(
                delayMs: 180,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Brand.blue, Brand.blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Brand.blue.withValues(alpha: 0.30), blurRadius: 16, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daily Challenge', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                                Text('5 Questions • new every day', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          if (dailyDone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: Brand.green, borderRadius: BorderRadius.circular(99)),
                              child: const Text('Done ✓', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      PressScale(
                        onTap: () => startQuiz(context, questions: bank.daily(DateTime.now()), title: 'Daily Challenge', isDaily: true),
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Brand.gold, borderRadius: BorderRadius.circular(14)),
                          child: Text(dailyDone ? 'Play Again' : 'Play Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Brand.navy)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                delayMs: 240,
                child: Row(
                  children: [
                    const Text('Choose a Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.ink)),
                    const Spacer(),
                    PressScale(
                      onTap: onSeeAll,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Brand.blue)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.86),
                itemBuilder: (context, i) {
                  final cat = kCategories[i];
                  return FadeSlideIn(
                    delayMs: 260 + i * 55,
                    child: PressScale(
                      onTap: () => startQuiz(context, questions: bank.forCategory(cat.name, 10, store.seenIds), title: cat.name, isDaily: false, category: cat.name),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                              child: Icon(cat.icon, color: cat.color, size: 25),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(cat.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Brand.ink)),
                            ),
                            Text('${bank.countFor(cat.name)} questions', style: const TextStyle(fontSize: 10, color: Brand.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsePlay extends StatefulWidget {
  final VoidCallback onTap;
  const _PulsePlay({required this.onTap});

  @override
  State<_PulsePlay> createState() => _PulsePlayState();
}

class _PulsePlayState extends State<_PulsePlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

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
        return Transform.scale(
          scale: 1 + 0.025 * t,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Brand.blue.withValues(alpha: 0.25 + 0.18 * t), blurRadius: 18 + 10 * t, offset: const Offset(0, 8))],
            ),
            child: child,
          ),
        );
      },
      child: PressScale(
        onTap: widget.onTap,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Brand.blueDark]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Text('PLAY', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              SizedBox(width: 10),
              Text('• 10 mixed questions', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CATEGORIES TAB
// ---------------------------------------------------------------------------

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final bank = QuestionBank.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text('Categories', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Brand.ink)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: kCategories.length,
            itemBuilder: (context, i) {
              final cat = kCategories[i];
              return FadeSlideIn(
                delayMs: i * 60,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PressScale(
                    onTap: () => startQuiz(context, questions: bank.forCategory(cat.name, 10, store.seenIds), title: cat.name, isDaily: false, category: cat.name),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                            child: Icon(cat.icon, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Brand.ink)),
                                Text('${bank.countFor(cat.name)} questions', style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Brand.inkSoft),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// STATS TAB
// ---------------------------------------------------------------------------

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FadeSlideIn(child: Text('Your Progress', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Brand.ink))),
              const SizedBox(height: 16),
              FadeSlideIn(
                delayMs: 60,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(color: Color(0xFFFFF3D6), shape: BoxShape.circle),
                            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFF5A623), size: 26),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Level ${store.level}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Brand.ink)),
                              Text(store.levelTitle, style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft)),
                            ],
                          ),
                          const Spacer(),
                          Text('${store.xpInLevel} / 250 XP', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Brand.inkSoft)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: store.xpInLevel / 250),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: const Color(0xFFE8EEF9), valueColor: const AlwaysStoppedAnimation<Color>(Brand.blue)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delayMs: 120,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(
                    children: [
                      _StatCol(value: store.totalAnswered, label: 'Questions'),
                      _StatCol(value: store.totalCorrect, label: 'Correct'),
                      Expanded(
                        child: Column(
                          children: [
                            CountUp(value: (store.accuracy * 100).round(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.ink)),
                            const Text('Accuracy %', style: TextStyle(fontSize: 12, color: Brand.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delayMs: 180,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.refresh_rounded, color: Brand.blue, label: 'Rounds Played', value: '${store.roundsPlayed}'),
                      const Divider(height: 1, indent: 60),
                      _InfoRow(icon: Icons.star_rounded, color: const Color(0xFFF5A623), label: 'Best Round', value: '${store.bestRound} / 10'),
                      const Divider(height: 1, indent: 60),
                      _InfoRow(icon: Icons.local_fire_department_rounded, color: const Color(0xFFEA580C), label: 'Daily Streak', value: '${store.streak} ${store.streak == 1 ? 'day' : 'days'}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCol extends StatelessWidget {
  final int value;
  final String label;
  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CountUp(value: value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.ink)),
          Text(label, style: const TextStyle(fontSize: 12, color: Brand.inkSoft)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Brand.ink))),
          Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Brand.ink)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROFILE TAB + SETTINGS
// ---------------------------------------------------------------------------

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            children: [
              FadeSlideIn(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Brand.blueDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: Brand.blue.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: ClipOval(child: Image.asset('assets/images/owl_mascot.png', fit: BoxFit.cover)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Brain Explorer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Brand.ink)),
                    const SizedBox(height: 3),
                    Text('Level ${store.level} • ${store.xpInLevel}/250 XP', style: const TextStyle(fontSize: 13, color: Brand.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delayMs: 80,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    children: [
                      _MenuRow(icon: Icons.emoji_events_rounded, color: const Color(0xFFF5A623), label: 'My Achievements', onTap: () {
                        Navigator.of(context).push(FadeSlideRoute(builder: (_) => const AchievementsPage()));
                      }),
                      const Divider(height: 1, indent: 60),
                      _MenuRow(icon: Icons.local_fire_department_rounded, color: const Color(0xFFEA580C), label: 'Daily Streak', trailing: '${store.streak} ${store.streak == 1 ? 'day' : 'days'}'),
                      const Divider(height: 1, indent: 60),
                      _MenuRow(icon: Icons.settings_rounded, color: Brand.inkSoft, label: 'Settings', onTap: () {
                        Navigator.of(context).push(FadeSlideRoute(builder: (_) => const SettingsPage()));
                      }),
                      const Divider(height: 1, indent: 60),
                      _MenuRow(icon: Icons.shield_rounded, color: Brand.blue, label: 'Privacy Policy', onTap: () {
                        Navigator.of(context).push(FadeSlideRoute(builder: (_) => const PrivacyPage()));
                      }),
                      const Divider(height: 1, indent: 60),
                      _MenuRow(icon: Icons.info_rounded, color: Brand.inkSoft, label: 'About', onTap: () => _showAbout(context)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/owl_mascot.png', width: 74, height: 74),
            const SizedBox(height: 10),
            const Text('QuizNova', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const Text('Version 1.0.0', style: TextStyle(color: Brand.inkSoft, fontSize: 13)),
            const SizedBox(height: 10),
            const Text('Small Questions. Big Discoveries.\nA friendly trivia game for curious minds.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _MenuRow({required this.icon, required this.color, required this.label, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Brand.ink))),
            if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Brand.inkSoft)),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: Brand.inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Brand.bg, elevation: 0),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: Brand.blue.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.volume_up_rounded, color: Brand.blue, size: 19),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Sound Effects', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Brand.ink))),
                          Switch(
                            value: store.soundOn,
                            activeThumbColor: Brand.blue,
                            onChanged: (v) {
                              store.setSound(v);
                              if (v) SystemSound.play(SystemSoundType.click);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 60),
                    const _InfoRow(icon: Icons.info_rounded, color: Brand.inkSoft, label: 'Version', value: '1.0.0'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: PressScale(
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        title: const Text('Reset progress?'),
                        content: const Text('This clears your coins, XP, streak and all stats on this device.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Brand.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.resetAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress has been reset.')));
                      }
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Brand.red, size: 21),
                        SizedBox(width: 12),
                        Text('Reset Progress', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Brand.red)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Store.instance;
    final items = <(IconData, String, String, bool)>[
      (Icons.flag_rounded, 'First Steps', 'Finish your first round', s.roundsPlayed >= 1),
      (Icons.thumb_up_rounded, 'Getting Warm', 'Answer 50 questions correctly', s.totalCorrect >= 50),
      (Icons.psychology_rounded, 'Sharp Mind', 'Score 8 or more in one round', s.bestRound >= 8),
      (Icons.workspace_premium_rounded, 'Perfect Ten', 'Get a flawless 10 / 10 round', s.bestRound >= 10),
      (Icons.local_fire_department_rounded, 'On Fire', 'Reach a 3-day streak', s.streak >= 3),
      (Icons.monetization_on_rounded, 'Coin Collector', 'Hold 500 coins', s.coins >= 500),
      (Icons.school_rounded, 'Scholar', 'Answer 200 questions', s.totalAnswered >= 200),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('My Achievements', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Brand.bg, elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final (icon, title, desc, unlocked) = items[i];
          return FadeSlideIn(
            delayMs: i * 55,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: unlocked ? const Color(0xFFFFF3D6) : const Color(0xFFEEF1F6), shape: BoxShape.circle),
                    child: Icon(icon, color: unlocked ? const Color(0xFFF5A623) : Brand.inkSoft, size: 24),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: unlocked ? Brand.ink : Brand.inkSoft)),
                        Text(desc, style: const TextStyle(fontSize: 12.5, color: Brand.inkSoft)),
                      ],
                    ),
                  ),
                  Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_rounded, color: unlocked ? Brand.green : const Color(0xFFC4CEDD), size: 22),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Brand.bg, elevation: 0),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Text(
          'QuizNova Privacy Policy (MVP test build)\n\n'
          '• Your game progress — coins, XP, streaks and stats — is stored only on your device. We do not run accounts and we do not collect your name, email or location.\n\n'
          '• QuizNova shows ads provided by Google AdMob. In this test build, only Google\'s official test ads are used. Google may use a device advertising identifier to serve and measure ads, as described in Google\'s own privacy policy.\n\n'
          '• The trivia questions live inside the app; playing the game works offline. An internet connection is only used to load ads.\n\n'
          '• You can erase all locally stored progress at any time from Settings → Reset Progress, or by clearing the app\'s storage / uninstalling the app.\n\n'
          'Questions about this policy can be sent to the developer through the app store listing.',
          style: TextStyle(fontSize: 14, height: 1.55, color: Brand.ink),
        ),
      ),
    );
  }
}
