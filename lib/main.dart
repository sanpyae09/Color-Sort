import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'data.dart';
import 'services.dart';

final Store store = Store();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // WHITE-SCREEN FIX (v1.1, user report 2026-11-04 ~22:24): v1 awaited
  // JustAudioBackground.init + tts.init + store.load BEFORE runApp, so if
  // any one of those platform calls stalls on a phone, Flutter never
  // renders its first frame and the user sees only a white screen.
  // Now the app runs FIRST, and all three inits happen in the background,
  // each capped at 8 seconds, errors swallowed. A failed/slow init must
  // never block the UI again; saved settings apply via notifyListeners
  // when store.load finishes, and TTS re-inits on first speak if needed.
  runApp(const NuvessaApp());
  unawaited(_initInBackground());
}

Future<void> _initInBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.pyaystudios.nuvessa.audio',
      androidNotificationChannelName: 'NUVESSA Listening',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // Audio background service unavailable/slow: Listen Mode still opens;
    // playback falls back to the in-app player path in ListenPlayer.
  } finally {
    listenPlayer.markAudioReady();
  }
  try {
    await tts.init().timeout(const Duration(seconds: 8));
  } catch (_) {}
  try {
    await store.load().timeout(const Duration(seconds: 8));
  } catch (_) {}
}

class NuvessaApp extends StatelessWidget {
  const NuvessaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return MaterialApp(
          title: 'NUVESSA',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F2FF),
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF1E1B2E),
          ),
          themeMode: store.darkTheme ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ---------- shared UI helpers (match the sent mockup) ----------
LinearGradient get purpleGradient => const LinearGradient(
      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

LinearGradient gradientOf(Course c) => LinearGradient(
      colors: [Color(c.color), Color(c.color2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

BoxDecoration cardDec(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? const Color(0xFF2A2540) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

Widget primaryButton(String label, VoidCallback onTap, {IconData? icon}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 18),
          ],
        ],
      ),
    ),
  );
}

Widget progressRing(int pct, double size) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: pct / 100.0,
            strokeWidth: 7,
            backgroundColor: const Color(0xFFE9E5FF),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
          ),
        ),
        Text('$pct%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

void snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ---------- splash (screen 1 of the mockup) ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF2563EB), Color(0xFF7C3AED)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(36),
                ),
                alignment: Alignment.center,
                child: const Text('N',
                    style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(height: 20),
              const Text('NUVESSA',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Learn Every Language.\nUnlock Every World.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 40),
              const SizedBox(
                width: 160,
                child: LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- main shell with bottom nav ----------
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  void goTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeTab(onExplore: () => goTab(2)),
      const PracticeTab(),
      const CoursesTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: goTab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Practice'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------- home (screen 2) ----------
class HomeTab extends StatelessWidget {
  final VoidCallback onExplore;
  const HomeTab({super.key, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final lang = store.langCode == 'ms' ? malay : english;
    final phrase = phrases[DateTime.now().day % phrases.length];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      gradient: purpleGradient,
                      borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: const Text('N',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ),
                const SizedBox(width: 8),
                const Text('NUVESSA',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => snack(context, 'No new notifications yet.'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF2563EB),
                    Color(0xFF7C3AED),
                    Color(0xFFDB2777)
                  ]),
                  borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${store.userName}! 👋',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                            "Let's explore a new language today!",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                  const Icon(Icons.public, color: Colors.white, size: 44),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onExplore,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward,
                          color: Color(0xFF7C3AED), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Choose a Language',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: () => snack(context,
                        'More languages are coming soon. English and Bahasa Malaysia first in v1.'),
                    child: const Text('See All >')),
              ],
            ),
            const SizedBox(height: 8),
            _LanguageGrid(),
            const SizedBox(height: 20),
            const Text('Your Progress',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProgressScreen())),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDec(context),
                child: Row(
                  children: [
                    progressRing(store.progressPct, 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Beginner Level',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                              'Learning ${lang.name} • ${store.lessonsDone} course(s) done',
                              style: const TextStyle(color: Colors.grey)),
                          const Text('Keep going!',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.bar_chart, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Listen Mode - the screen-off feature, prominent on Home.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  gradient: purpleGradient,
                  borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.headphones, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text('Listen Mode 🎧',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Plug in your earphones, lock the phone, and keep learning. The lesson keeps playing on the lock screen.',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ListenScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Start listening',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("Today's phrase",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDec(context),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(phrase.inLang(store.langCode),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(phrase.my,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up,
                        color: Color(0xFF7C3AED)),
                    onPressed: () =>
                        tts.speak(phrase.inLang(store.langCode), store.langCode),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LanguageGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const langs = [
      ('en', 'English', '🇺🇸', true),
      ('ms', 'Malaysia', '🇲🇾', true),
      ('es', 'Spanish', '🇪🇸', false),
      ('fr', 'French', '🇫🇷', false),
      ('de', 'German', '🇩🇪', false),
      ('ja', 'Japanese', '🇯🇵', false),
      ('zh', 'Chinese', '🇨🇳', false),
      ('ko', 'Korean', '🇰🇷', false),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
      itemCount: langs.length,
      itemBuilder: (context, i) {
        final l = langs[i];
        final selected = store.langCode == l.$1 && l.$4;
        return GestureDetector(
          onTap: () {
            if (!l.$4) {
              snack(context,
                  '${l.$2} is coming soon. English and Bahasa Malaysia first in v1.');
              return;
            }
            store.setLang(l.$1);
            snack(context, 'Learning language: ${l.$2}');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2540)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: const Color(0xFF7C3AED), width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.$3, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                Text(l.$2,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (!l.$4)
                  const Text('Soon',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                if (selected)
                  const Icon(Icons.check_circle,
                      size: 14, color: Color(0xFF22C55E)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------- practice tab (speaking / translation / AI / listen) ----------
class PracticeTab extends StatelessWidget {
  const PracticeTab({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Speaking Practice', 'Say it out loud, get instant feedback.',
          Icons.mic, const SpeakingScreen()),
      ('Translation', 'English ⇄ Bahasa Malaysia, with sound.',
          Icons.translate, const TranslationScreen()),
      ('AI Conversation', 'Chat with NUVESSA about travel, hobbies and daily life.',
          Icons.smart_toy, const AiScreen()),
      ('Listen Mode', 'Screen off, earphones on. Lessons keep playing.',
          Icons.headphones, const ListenScreen()),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Practice',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Learning ${store.langCode == 'ms' ? 'Bahasa Malaysia' : 'English'} today',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          for (final it in items) ...[
            GestureDetector(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => it.$4)),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDec(context),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          gradient: purpleGradient,
                          borderRadius: BorderRadius.circular(16)),
                      child: Icon(it.$3, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.$1,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(it.$2,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ---------- courses / explore (screen 3) ----------
class CoursesTab extends StatefulWidget {
  const CoursesTab({super.key});
  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  String _tag = 'All';
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final mine = courses.where((c) => c.langCode == store.langCode).toList();
    final filtered = mine.where((c) {
      final tagOk = _tag == 'All' || c.tag == _tag;
      final qOk = _query.isEmpty ||
          c.title.toLowerCase().contains(_query.toLowerCase());
      return tagOk && qOk;
    }).toList();
    const tags = ['All', 'Popular', 'Business', 'Travel'];
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {}),
                const Expanded(
                  child: Text('Courses',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.search),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search courses…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2540)
                    : Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in tags)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: _tag == t,
                      onSelected: (_) => setState(() => _tag = t),
                      selectedColor: const Color(0xFF7C3AED),
                      labelStyle: TextStyle(
                          color: _tag == t ? Colors.white : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No course in this filter yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      final done = store.doneCourses.contains(c.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: cardDec(context),
                        child: Row(
                          children: [
                            Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                  gradient: gradientOf(c),
                                  borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      bottomLeft: Radius.circular(20))),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.location_city,
                                      color: Colors.white, size: 34),
                                  const SizedBox(height: 6),
                                  Text(c.tag,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(c.subtitle,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.people,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(c.learners,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12)),
                                        if (done) ...[
                                          const SizedBox(width: 8),
                                          const Icon(Icons.check_circle,
                                              size: 14,
                                              color: Color(0xFF22C55E)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => LessonScreen(course: c))),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      gradient: purpleGradient,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.play_arrow,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- lesson quiz (screen 4) ----------
class LessonScreen extends StatefulWidget {
  final Course course;
  const LessonScreen({super.key, required this.course});
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final List<QuizQ> _qs = quizFor(widget.course);
  int _i = 0;
  int _score = 0;
  String? _picked;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (store.autoPlayAudio) {
      Future.delayed(const Duration(milliseconds: 400), _speakPrompt);
    }
  }

  void _speakPrompt() {
    if (_i < _qs.length) tts.speak(_qs[_i].prompt, _qs[_i].promptLang);
  }

  void _pick(String opt) {
    if (_picked != null) return;
    final correct = opt == _qs[_i].answer;
    setState(() {
      _picked = opt;
      if (correct) _score++;
    });
  }

  void _next() {
    if (_i + 1 >= _qs.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _i++;
      _picked = null;
    });
    if (store.autoPlayAudio) _speakPrompt();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson complete')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text('You scored $_score / ${_qs.length}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(widget.course.title,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              primaryButton('Save progress & go back', () async {
                await store.completeCourse(widget.course.id, 5);
                if (mounted) Navigator.of(context).pop();
              }),
            ],
          ),
        ),
      );
    }
    final q = _qs[_i];
    final my = myMeaningOf(q.prompt, q.promptLang);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop()),
        title: Text('${_i + 1}/${_qs.length}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (_i + 1) / _qs.length.toDouble(),
              color: const Color(0xFF7C3AED),
              backgroundColor: const Color(0xFFE9E5FF),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                  gradient: gradientOf(widget.course),
                  borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_city,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(widget.course.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('What does this mean?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(q.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.volume_up,
                          color: Color(0xFF7C3AED)),
                      onPressed: _speakPrompt),
                ],
              ),
            ),
            if (my.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Hint (Burmese): $my',
                  style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            for (final opt in q.options) ...[
              GestureDetector(
                onTap: () => _pick(opt),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _picked == null
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2540)
                            : Colors.white)
                        : opt == q.answer
                            ? const Color(0xFFDCFCE7)
                            : opt == _picked
                                ? const Color(0xFFFEE2E2)
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2A2540)
                                    : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _picked != null && opt == q.answer
                            ? const Color(0xFF22C55E)
                            : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(opt,
                              style: const TextStyle(fontSize: 16))),
                      if (_picked != null && opt == q.answer)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF22C55E)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            primaryButton(_i + 1 >= _qs.length ? 'See result' : 'Next >',
                _picked == null ? () {} : _next),
            if (_picked == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Pick an answer first.',
                    style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- speaking practice (screen 5) ----------
class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({super.key});
  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  final SpeechToText _stt = SpeechToText();
  int _pi = 0;
  bool _listening = false;
  bool _great = false;
  String _heard = '';
  String _note = '';

  Phrase get _phrase => phrases[_pi];
  String get _target => _phrase.inLang(store.langCode);

  String _clean(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _stt.initialize(
      onError: (_) => setState(() {
        _listening = false;
        _note = 'Microphone is not available on this device. Use Listen and repeat out loud instead.';
      }),
    );
    if (!ok) {
      setState(() => _note =
          'Microphone is not available on this device. Use Listen and repeat out loud instead.');
      return;
    }
    setState(() {
      _listening = true;
      _great = false;
      _heard = '';
      _note = 'Listening… speak now.';
    });
    await _stt.listen(
      localeId: store.langCode == 'ms' ? 'ms_MY' : 'en_US',
      onResult: (r) {
        setState(() {
          _heard = r.recognizedWords;
          if (_clean(_heard).contains(_clean(_target)) ||
              _clean(_target).contains(_clean(_heard)) &&
                  _heard.trim().isNotEmpty) {
            _great = true;
            _note = 'Great! Keep going!';
          }
        });
        if (r.finalResult) setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('Speaking Practice'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _toggleMic,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: purpleGradient,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: _listening ? 12 : 2),
                  ],
                ),
                child: Icon(_listening ? Icons.mic : Icons.mic_none,
                    color: Colors.white, size: 72),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Tap to Speak',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Say: "$_target"',
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
            Text(_phrase.my, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 12; i++)
                  Container(
                    width: 5,
                    height: _listening ? (20.0 + (i % 5) * 12.0) : 14,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        color: _listening
                            ? const Color(0xFF7C3AED)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_heard.isNotEmpty)
              Text('You said: "$_heard"',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            if (_note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _great
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(14)),
                child: Text(
                    _great ? '⭐ Great! Keep going!' : _note,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => tts.speak(_target, store.langCode),
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Listen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      _pi = (_pi + 1) % phrases.length;
                      _great = false;
                      _heard = '';
                      _note = '';
                    }),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white),
                    child: const Text('Next phrase'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- translation (screen 6) ----------
class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});
  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _ctrl = TextEditingController(text: 'Hello, how are you?');
  String _from = 'en';
  String _to = 'ms';
  String? _result;
  final SpeechToText _stt = SpeechToText();

  void _doTranslate() {
    final out = translateLookup(_ctrl.text, _from, _to);
    setState(() {
      _result = out ??
          'Not in the v1 dictionary yet. Try: Good morning, Thank you very much, Where are you from?';
    });
  }

  @override
  void initState() {
    super.initState();
    _doTranslate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('Translation'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _modeChip('Text', true, () {})),
                const SizedBox(width: 8),
                Expanded(
                  child: _modeChip('Voice', false, () async {
                    final ok = await _stt.initialize();
                    if (!ok) {
                      snack(context, 'Voice input is not available here.');
                      return;
                    }
                    await _stt.listen(
                      localeId: _from == 'ms' ? 'ms_MY' : 'en_US',
                      onResult: (r) {
                        if (r.finalResult) {
                          setState(() => _ctrl.text = r.recognizedWords);
                          _doTranslate();
                        }
                      },
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2540)
                    : Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _ctrl.clear())),
              ),
              onSubmitted: (_) => _doTranslate(),
            ),
            const SizedBox(height: 12),
            primaryButton('✦ Translate', _doTranslate),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _langChip('English', 'en'),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.swap_horiz)),
                _langChip('Bahasa Malaysia', 'ms'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tap a language to change direction. Current: ${_from == 'en' ? 'English → Bahasa Malaysia' : 'Bahasa Malaysia → English'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: cardDec(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_to == 'ms' ? '🇲🇾' : '🇺🇸',
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(_to == 'ms' ? 'Bahasa Malaysia' : 'English',
                            style: const TextStyle(color: Colors.grey)),
                        const Spacer(),
                        IconButton(
                            icon: const Icon(Icons.volume_up,
                                color: Color(0xFF7C3AED)),
                            onPressed: () => tts.speak(_result!, _to)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_result!,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _actionBtn(Icons.copy, 'Copy', () {
                          Clipboard.setData(ClipboardData(text: _result!));
                          snack(context, 'Copied.');
                        }),
                        _actionBtn(Icons.share, 'Share', () {
                          Share.share(_result!);
                        }),
                        _actionBtn(Icons.volume_up, 'Listen', () {
                          tts.speak(_result!, _to);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Try these phrases',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in phrases.take(6))
                  ActionChip(
                    label: Text(p.inLang(_from)),
                    onPressed: () {
                      setState(() => _ctrl.text = p.inLang(_from));
                      _doTranslate();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: active ? const Color(0xFF7C3AED) : Colors.white,
            borderRadius: BorderRadius.circular(22)),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _langChip(String label, String code) {
    final active = _to == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _to = code;
          _from = code == 'ms' ? 'en' : 'ms';
        });
        _doTranslate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: active ? const Color(0xFFEDE9FE) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active
                    ? const Color(0xFF7C3AED)
                    : Colors.grey.shade300)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------- AI conversation (screen 7) ----------
class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final List<(bool, String)> _msgs = [
    (false, 'Hi! 👋 How can I help you today?'),
  ];

  String _reply(String input) {
    final q = input.toLowerCase();
    final lang = store.langCode;
    final p = phrases[DateTime.now().second % phrases.length];
    if (q.contains('travel')) {
      return lang == 'ms'
          ? 'Untuk melancong, cuba: "Di mana tandas?" — Where is the toilet?'
          : 'For travel, try: "Where is the toilet?" — practise it in Speaking Practice too.';
    }
    if (q.contains('hobb')) {
      return lang == 'ms'
          ? 'Hobi saya ialah belajar bahasa! Apa hobi anda?'
          : 'My hobby is learning languages! What is your hobby?';
    }
    if (q.contains('hello') || q.contains('hi')) {
      return lang == 'ms' ? 'Selamat pagi! Apa khabar?' : 'Good morning! How are you?';
    }
    if (q.contains('thank')) {
      return lang == 'ms' ? 'Sama-sama! Terima kasih juga.' : "You're welcome!";
    }
    return 'Nice! Try saying: "${p.inLang(lang)}" — ${p.my}';
  }

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _msgs.add((true, text));
      _msgs.add((false, _reply(text)));
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('AI Conversation'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                gradient: purpleGradient, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (context, i) {
                final m = _msgs[i];
                return Align(
                  alignment:
                      m.$1 ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: m.$1
                          ? const Color(0xFF7C3AED)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A2540)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(m.$2,
                              style: TextStyle(
                                  color: m.$1 ? Colors.white : null)),
                        ),
                        if (!m.$1) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () =>
                                tts.speak(m.$2, store.langCode),
                            child: const Icon(Icons.volume_up,
                                size: 18, color: Color(0xFF7C3AED)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in [
                  "Let's talk about travel.",
                  'Tell me about your hobbies.',
                  'Practice daily conversation.'
                ])
                  ActionChip(
                      label: Text(s), onPressed: () => _send(s)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      filled: true,
                      fillColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2A2540)
                              : Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        gradient: purpleGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- listen mode: screen-off listening (the user's key request) ----------
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});
  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  ListenLesson _lesson =
      listenLessons.firstWhere((l) => l.langCode == store.langCode,
          orElse: () => listenLessons.first);
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  @override
  void initState() {
    super.initState();
    _stateSub = listenPlayer.stateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
    });
    _posSub = listenPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _durSub = listenPlayer.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _dur = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = listenPlayer.current?.id == _lesson.id;
    final progress = _dur.inMilliseconds == 0
        ? 0.0
        : _pos.inMilliseconds / _dur.inMilliseconds.toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('Listen Mode'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  gradient: purpleGradient,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                children: [
                  Icon(Icons.headphones, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'Lock your phone. The lesson keeps playing with your earphones, with lock-screen controls.',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose a listening lesson',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final l in listenLessons) ...[
              GestureDetector(
                onTap: () => setState(() => _lesson = l),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _lesson.id == l.id
                        ? const Color(0xFFEDE9FE)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2540)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: _lesson.id == l.id
                        ? Border.all(color: const Color(0xFF7C3AED))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(l.langCode == 'ms' ? '🇲🇾' : '🇺🇸',
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(l.subtitle,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (_lesson.id == l.id)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF7C3AED)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDec(context),
              child: Column(
                children: [
                  Text(_lesson.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(isCurrent && _playing ? 'Now playing' : 'Paused',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Slider(
                    value: progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0).toDouble(),
                    onChanged: (v) {
                      if (_dur.inMilliseconds > 0) {
                        listenPlayer.seek(Duration(
                            milliseconds:
                                (v * _dur.inMilliseconds).round()));
                      }
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(_fmt(_pos)), Text(_fmt(_dur))],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed: () => listenPlayer.seek(
                            _pos - const Duration(seconds: 10)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          if (isCurrent) {
                            await listenPlayer.toggle();
                          } else {
                            await listenPlayer.playLesson(_lesson);
                          }
                        },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                              gradient: purpleGradient,
                              shape: BoxShape.circle),
                          child: Icon(
                              isCurrent && _playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 36),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed: () => listenPlayer.seek(
                            _pos + const Duration(seconds: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await listenPlayer.stop();
                      await store.addStudyMinutes(1);
                    },
                    child: const Text('Stop & save 1 min study time'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('In this lesson',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final p in _lesson.lines.take(10)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(p.inLang(_lesson.langCode),
                            style: const TextStyle(fontSize: 15))),
                    Text(p.my,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
                'How screen-off works: this lesson is a real media playback session. When you lock the phone, Android keeps the media session alive, shows it on the lock screen, and your earphone buttons control play / pause.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------- my progress (screen 8) ----------
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _tab = 'Overview';
  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxMin =
        store.dayMinutes.values.fold<int>(1, (a, b) => b > a ? b : a);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('My Progress'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final t in ['Overview', 'Learning', 'Goals'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: _tab == t,
                      onSelected: (_) => setState(() => _tab = t),
                      selectedColor: const Color(0xFF7C3AED),
                      labelStyle: TextStyle(
                          color: _tab == t ? Colors.white : null),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDec(context),
              child: Row(
                children: [
                  progressRing(store.progressPct, 88),
                  const SizedBox(width: 18),
                  const Text('Overall\nProgress',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stat(Icons.menu_book, '${store.lessonsDone}', 'Lessons'),
                      const SizedBox(height: 8),
                      _stat(Icons.timer, '${store.studyMinutes} min',
                          'Study Time'),
                      const SizedBox(height: 8),
                      _stat(Icons.local_fire_department,
                          '${store.streakDays} Days', 'Streak'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Weekly Activity',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('View Details >',
                    style: TextStyle(color: Color(0xFF7C3AED))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 130,
              padding: const EdgeInsets.all(16),
              decoration: cardDec(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final d in days)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 18,
                          height: (12.0 +
                                  ((store.dayMinutes[d] ?? 0) * 70.0 / maxMin)
                                      .clamp(0.0, 70.0))
                              .toDouble(),
                          decoration: BoxDecoration(
                              color: (store.dayMinutes[d] ?? 0) > 0
                                  ? const Color(0xFF7C3AED)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        const SizedBox(height: 6),
                        Text(d, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Completed courses',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (store.doneCourses.isEmpty)
              const Text('No course completed yet. Finish a lesson to see it here.',
                  style: TextStyle(color: Colors.grey))
            else
              for (final id in store.doneCourses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF22C55E), size: 18),
                      const SizedBox(width: 8),
                      Text(courses
                          .firstWhere((c) => c.id == id,
                              orElse: () => courses.first)
                          .title),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// ---------- profile tab (screen 9) ----------
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    final initial =
        store.userName.isNotEmpty ? store.userName[0].toUpperCase() : 'L';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF7C3AED),
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(store.userName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
                '${store.langCode == 'ms' ? 'Bahasa Malaysia' : 'English'} learner • NUVESSA',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final ctrl = TextEditingController(text: store.userName);
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Your name'),
                    content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                            hintText: 'e.g. Pyay')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(ctrl.text),
                          child: const Text('Save')),
                    ],
                  ),
                );
                if (name != null) await store.setName(name);
              },
              child: const Text('Edit name'),
            ),
            const SizedBox(height: 12),
            _menuItem(context, Icons.bar_chart, 'My Progress', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProgressScreen()));
            }),
            _menuItem(context, Icons.emoji_events, 'Achievements', () {
              final n = store.lessonsDone;
              snack(
                  context,
                  n == 0
                      ? 'No achievement yet. Finish your first course to unlock First Steps.'
                      : 'Unlocked: First Steps${n >= 3 ? ', Triple Learner' : ''} • $n course(s) done.');
            }),
            _menuItem(context, Icons.flag, 'Language Goals', () {
              snack(context,
                  'Current goal: ${store.langCode == 'ms' ? 'Bahasa Malaysia' : 'English'} everyday conversation. Change it on Home > Choose a Language.');
            }),
            _menuItem(context, Icons.settings, 'Settings', () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _menuItem(context, Icons.help_outline, 'Help & Support', () {
              showDialog(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Help & Support'),
                  content: Text(
                      'NUVESSA v1.0.0\n\n• Lessons work offline.\n• Listen Mode keeps playing with the screen locked.\n• Speaking needs a microphone and your phone speech recognition.\n• Translation in v1 covers the everyday phrases in the app.'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDec(context),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF7C3AED)),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// ---------- settings (screen 10) ----------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Preferences',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: cardDec(context),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Language'),
                    subtitle: Text(store.langCode == 'ms'
                        ? 'Bahasa Malaysia'
                        : 'English'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      store.setLang(store.langCode == 'ms' ? 'en' : 'ms');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.brightness_6),
                    title: const Text('Theme'),
                    subtitle:
                        Text(store.darkTheme ? 'Dark' : 'Light'),
                    trailing: Switch(
                        value: store.darkTheme,
                        onChanged: (v) => store.toggleDark(v)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications),
                    title: const Text('Notifications'),
                    value: store.notificationsOn,
                    onChanged: (v) => store.toggleNotifications(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Learning Settings',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: cardDec(context),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Daily Reminder'),
                    subtitle: Text(store.reminderTime),
                    trailing:
                        const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 20, minute: 0));
                      if (t != null) {
                        final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
                        final mm = t.minute.toString().padLeft(2, '0');
                        final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
                        await store.setReminder('$h:$mm $ap');
                      }
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up),
                    title: const Text('Auto Play Audio'),
                    subtitle: const Text('Hear each lesson word automatically'),
                    value: store.autoPlayAudio,
                    onChanged: (v) => store.toggleAutoPlay(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Listen Mode',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDec(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Lessons play as a real media session, so they keep playing when the screen is locked. Use your earphone buttons for play / pause.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  primaryButton('Open Listen Mode', () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ListenScreen()));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('About',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: cardDec(context),
              child: ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About NUVESSA'),
                subtitle: const Text(
                    'v1.0.0 • Learn Every Language. Unlock Every World. English and Bahasa Malaysia first.'),
                onTap: () => snack(context, 'NUVESSA v1.0.0 — made for learners.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
