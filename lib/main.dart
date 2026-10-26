import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const BlockPuzzleApp());
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// Board size, exactly as in the user's reference pictures: 8x8.
/// (NOT 10x10 — the first build used 10x10 from web articles and the user
/// corrected it: his pictures show an 8x8 board.)
const int kBoard = 8;

/// A piece shape, written as rows of '1'/'0' characters.
class Shape {
  final List<String> rows;
  const Shape(this.rows);

  List<Point<int>> get cells {
    final out = <Point<int>>[];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        if (rows[r][c] == '1') out.add(Point(r, c));
      }
    }
    return out;
  }

  int get height => rows.length;
  int get width => rows.fold<int>(0, (m, r) => max(m, r.length));
  int get size => cells.length;
}

const List<Shape> kShapes = [
  Shape(['1']),
  Shape(['11']),
  Shape(['1', '1']),
  Shape(['111']),
  Shape(['1', '1', '1']),
  Shape(['1111']),
  Shape(['1', '1', '1', '1']),
  Shape(['11111']),
  Shape(['11', '11']),
  Shape(['111', '111']),
  Shape(['111', '111', '111']),
  Shape(['11', '11', '11']),
  Shape(['111', '111']),
  Shape(['100', '111']),
  Shape(['001', '111']),
  Shape(['111', '100']),
  Shape(['111', '001']),
  Shape(['10', '10', '11']),
  Shape(['01', '01', '11']),
  Shape(['11', '10', '10']),
  Shape(['11', '01', '01']),
  Shape(['111', '010']),
  Shape(['010', '111']),
  Shape(['10', '11', '10']),
  Shape(['01', '11', '01']),
  Shape(['011', '110']),
  Shape(['110', '011']),
  Shape(['10', '11', '01']),
  Shape(['01', '11', '10']),
  Shape(['010', '111', '010']),
  Shape(['11', '10']),
  Shape(['11', '01']),
  Shape(['10', '11']),
  Shape(['01', '11']),
];

Shape randomShape(Random rng) {
  // Weight small pieces a little higher so the tray rarely strands the player.
  final bag = <Shape>[];
  for (final s in kShapes) {
    final w = s.size <= 2 ? 3 : (s.size <= 4 ? 3 : (s.size == 9 ? 1 : 2));
    for (var i = 0; i < w; i++) bag.add(s);
  }
  return bag[rng.nextInt(bag.length)];
}

class Piece {
  final Shape shape;
  final int color;
  final String id;
  Piece(this.shape, this.color, this.id);
}

class BlockTheme {
  final String name;
  final int price;
  final List<Color> colors;
  const BlockTheme(this.name, this.price, this.colors);
}

const List<BlockTheme> kBlockThemes = [
  BlockTheme('Default', 0, [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFFC107),
    Color(0xFF43A047),
    Color(0xFF00ACC1),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFEC407A),
  ]),
  BlockTheme('Wooden', 500, [
    Color(0xFF8D6E63),
    Color(0xFFA1887F),
    Color(0xFFBCAAA4),
    Color(0xFF6D4C41),
    Color(0xFFD7CCC8),
    Color(0xFF795548),
    Color(0xFF4E342E),
    Color(0xFFBCA188),
  ]),
  BlockTheme('Neon', 1000, [
    Color(0xFFFF1744),
    Color(0xFFFFEA00),
    Color(0xFF00E676),
    Color(0xFF00E5FF),
    Color(0xFF2979FF),
    Color(0xFFD500F9),
    Color(0xFF76FF03),
    Color(0xFFFF9100),
  ]),
  BlockTheme('Galaxy', 1500, [
    Color(0xFF311B92),
    Color(0xFF4527A0),
    Color(0xFF6A1B9A),
    Color(0xFF283593),
    Color(0xFF1565C0),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF4A148C),
  ]),
];

class BoardTheme {
  final String name;
  final Color frame;
  final Color cell;
  final Color bg;
  const BoardTheme(this.name, this.frame, this.cell, this.bg);
}

const List<BoardTheme> kBoardThemes = [
  BoardTheme('Cream Wood', Color(0xFF8D6E63), Color(0xFFE9CD9F), Color(0xFFFFF8E7)),
  BoardTheme('Dark Walnut', Color(0xFF4E342E), Color(0xFFEFEBE9), Color(0xFFEFEBE9)),
  BoardTheme('Mint', Color(0xFF2E7D6B), Color(0xFFE8F5E9), Color(0xFFF1F8E9)),
];

// ---------------------------------------------------------------------------
// Sound
// ---------------------------------------------------------------------------

class Sfx {
  static AudioPlayer? _sfx;
  static AudioPlayer? _music;
  static bool enabled = true;
  static bool musicEnabled = true;

  static Future<void> play(String name) async {
    if (!enabled) return;
    try {
      _sfx ??= AudioPlayer();
      await _sfx!.play(AssetSource('sfx/$name.wav'));
    } catch (_) {}
  }

  static Future<void> startMusic() async {
    if (!musicEnabled) return;
    try {
      _music ??= AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(0.25);
      await _music!.play(AssetSource('sfx/music.wav'));
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Persistent profile
// ---------------------------------------------------------------------------

class Profile {
  int best = 0;
  int coins = 0;
  int theme = 0;
  int boardTheme = 0;
  Set<int> ownedThemes = {0};
  bool sound = true;
  bool music = true;
  bool vibrate = true;
  String dailyDate = '';
  int dailyLines = 0;
  bool dailyClaimed = false;
  int totalCleared = 0;
  int bestCombo = 0;
  int maxLinesInMove = 0;
  int graphics = 1; // 0 Low, 1 Medium, 2 High
  int gamesPlayed = 0;
  int streakDays = 0;
  String lastPlayDate = '';
  Set<String> claimedAchievements = {};

  static String today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    best = p.getInt('best') ?? 0;
    coins = p.getInt('coins') ?? 0;
    theme = p.getInt('theme') ?? 0;
    boardTheme = p.getInt('boardTheme') ?? 0;
    ownedThemes = (p.getString('owned') ?? '0').split(',').map(int.parse).toSet();
    sound = p.getBool('sound') ?? true;
    music = p.getBool('music') ?? true;
    vibrate = p.getBool('vibrate') ?? true;
    dailyDate = p.getString('dailyDate') ?? '';
    dailyLines = p.getInt('dailyLines') ?? 0;
    dailyClaimed = p.getBool('dailyClaimed') ?? false;
    totalCleared = p.getInt('totalCleared') ?? 0;
    bestCombo = p.getInt('bestCombo') ?? 0;
    maxLinesInMove = p.getInt('maxLinesInMove') ?? 0;
    graphics = p.getInt('graphics') ?? 1;
    gamesPlayed = p.getInt('gamesPlayed') ?? 0;
    streakDays = p.getInt('streakDays') ?? 0;
    lastPlayDate = p.getString('lastPlayDate') ?? '';
    claimedAchievements = (p.getString('claimedAch') ?? '').split(',').where((e) => e.isNotEmpty).toSet();
    if (dailyDate != today()) {
      dailyDate = today();
      dailyLines = 0;
      dailyClaimed = false;
    }
    Sfx.enabled = sound;
    Sfx.musicEnabled = music;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('best', best);
    await p.setInt('coins', coins);
    await p.setInt('theme', theme);
    await p.setInt('boardTheme', boardTheme);
    await p.setString('owned', ownedThemes.join(','));
    await p.setBool('sound', sound);
    await p.setBool('music', music);
    await p.setBool('vibrate', vibrate);
    await p.setString('dailyDate', dailyDate);
    await p.setInt('dailyLines', dailyLines);
    await p.setBool('dailyClaimed', dailyClaimed);
    await p.setInt('totalCleared', totalCleared);
    await p.setInt('bestCombo', bestCombo);
    await p.setInt('maxLinesInMove', maxLinesInMove);
    await p.setInt('graphics', graphics);
    await p.setInt('gamesPlayed', gamesPlayed);
    await p.setInt('streakDays', streakDays);
    await p.setString('lastPlayDate', lastPlayDate);
    await p.setString('claimedAch', claimedAchievements.join(','));
  }

  void markPlayedToday() {
    final t = today();
    if (lastPlayDate != t) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      streakDays = (lastPlayDate == yKey) ? streakDays + 1 : 1;
      lastPlayDate = t;
    }
  }
}

final Profile profile = Profile();

// ---------------------------------------------------------------------------
// App shell
// ---------------------------------------------------------------------------

class BlockPuzzleApp extends StatelessWidget {
  const BlockPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E63)),
        fontFamily: 'Roboto',
      ),
      home: const LoadingScreen(),
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    profile.load().then((_) {
      if (profile.music) Sfx.startMusic();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFF8E7),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63))),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

Widget coinChip() {
  return Container(
    padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on, color: Color(0xFFFFB300), size: 20),
        const SizedBox(width: 4),
        Text('${profile.coins}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 6),
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Picture style: wood + cream + glossy blocks, exactly the reference look.
// ---------------------------------------------------------------------------

const Color kWoodDark = Color(0xFF6D4C2F);
const Color kWood = Color(0xFF8D6E63);
const Color kWoodLight = Color(0xFFA67C52);
const Color kCream = Color(0xFFFFF8E7);
const Color kCreamCard = Color(0xFFFDEBD0);

LinearGradient woodGradient() {
  return const LinearGradient(
    colors: [kWoodLight, kWood, kWoodDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Glossy block gradient: light top edge, base middle, darker bottom edge.
LinearGradient glossGradient(Color base) {
  return LinearGradient(
    colors: [
      Color.lerp(base, Colors.white, 0.35)!,
      base,
      Color.lerp(base, Colors.black, 0.18)!,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Wooden header strip used by every dialog, like the picture's brown bars.
Widget woodHeader(String title, {VoidCallback? onClose}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(gradient: woodGradient()),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        if (onClose != null)
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
      ],
    ),
  );
}

/// Transparent tap zone over a painted button in a panel artwork.
/// (fx1,fy1)-(fx2,fy2) are fractions of the artwork, grounded on the panel.
Widget _zone(double w, double h, double fx1, double fy1, double fx2, double fy2, VoidCallback onTap) {
  return Positioned(
    left: w * fx1,
    top: h * fy1,
    width: w * (fx2 - fx1),
    height: h * (fy2 - fy1),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.play('click');
        onTap();
      },
      child: const SizedBox.expand(),
    ),
  );
}

// Panel artworks embedded as JPEG (q88) base64: the browser file
// upload cannot attach separate PNGs (chooser fails), so the artwork
// travels inside this text file, which uploads reliably.
const String kHomePanelB64 =
    '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'
    '9pz4ZNjuyFciH3w0sqOMJeKuUHz5eU1BgsD5m1DG7Fh/TX+yk5Yyk9FqXtPVByT5mvWpsiO6VsPLbURjmBps9ztPraKVZSSOma5C'
    'V8vMRyjxUeX66z0b7OuFJkBAun7tynPN8r06SsfgqeUR8xNV5xdace4LXxxrIejJblt4O4W2sKB+YYollXqzw8mVeIDWOoU8M/MK'
    'C+IOs9MyOHF4tcO4omSJLBADSTyISMlSlKxjAAojQvqH1UZ8R1HdebAGnwNSPCniDEv+loUKXKSHVthcZ1xXytt21HuwdvdVnbhX'
    'KRg+Ffn5pjUszSymULS6/bXgl0tp+WyrG60Z+kdFeVaX0bxalPWVtYkMXqEnALgUFON7dFDqD7aO47wy+mlMsOrSpGObUElmjuoV'
    '185GwVt4Z/RXRWCOo91V27xZsraRz2qclXglePrphM4vZZUm02YheMlyQSvl88DAHvrPR4dUPdYNKead46aqxrrdYFnta7jcnuyY'
    'SCPArPclI7yax/xn18/q3VyYCTyoylxTSTkNND9zbPnuVn3VI694pTbi6tpM1FxuGOUNp/e8bzVjb+CPeRVfWKzPuT3LjOcceecU'
    'palunKnFn74mt9w3gHul6qo+boqVS8N/ls3O56K9Pg06uYgWxzT05YbZDhjqKlfueTztK9m6h7q0mpXKopVsRsfKsFw7g7ovVibg'
    '2hS4jqeR5tO+W85Ch4qSrceWfGtH6R4txl26KzdHfSohSPR57B5zy46KHfjz3HfQbibB3mY1UIuHa/n1UsUfMaC35hv/AGVwF5aH'
    'ErStSVpOUlJwUnxBpx8cXJaChc58pI3AXy83tIwfpqAhXyzXJpK4N1hug9E9oEq+Y4paTOhw0FyTOispAySt5IwPnrJRyTx6MJHl'
    'qmugY7526r2/WG36o0rO07dAfQ5zXZuLT1aVnKHQOnMhQCh7PbVJ8A7LMtfGjU67mylEmwwFQHFAer2peIJT5EJ2o01PxcsFltz/'
    'AMWzESHmkkrk4+5sjffJxzHfYdKifg/vPXLROpNYSSsvXu6ApUvc8ic4z8+9aOjfU02GzGS+Q2Av3J/wmSUxYCe/RXL2pCQnoBtU'
    'PqfVEDS2nHrzclLLDZCEpbHrKWTgAb/2wacl4HooY7sGqP8AhNak+JdIaah85xJugkOgDfsm08p/1zQfC6Q1tWyAdSlLWtsSr7Q8'
    '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'
    '3OAyPfTWeNimVpv0OLcH3ZsS4LHODHDsclKE+YB60Xw9Y25SAQpSOgwphQwKj4s1xRAWpR881Lst9sApuSoeSgCKsROIcEQma07r'
    'JV1nC3cfNXAKHIq+PyE470O8roIz5OCjT0lJwUrBSQCD5HoaF/hBW6TZON7N5LSUM3SG2O0QMBTzIwR7S2UHzCT4U305fm5kJMZ1'
    'wBxOyST1Hgf0UmIU2Yh9lwLHqZ1JXSMOxN0ZB8+OK67ckdaivSMHBzn2b16JHXf3UK5SD8xSfbedcmRjvFR3pHnXheNJyknMUgX/'
    'ADFQ2p3x+xOaVHCU8iiT0ADiCT81Ll/upCUlmZDeiSEBbLyC24PwknYj5vqqaIZHhy82XK4O81tZ2WyhCpC3m0tY5+cqGMeNUzxF'
    '+EPZtOPu2DSyVXe9H1ChlXqsk/hnBCT+KAVnwFZ7DmvFWdFhc13OVaUDkQ1khzk6BPON8Y22NKWyzW+zMhEJoBWd3F7k+Ph1/tmt'
    'ZUY6zL/LHiK0lRxF4MsQ1Xc6HfdZXxF+1zcVSnObmahIJS00PBKe4eJzzHvONqnW1ttsIaaSltCU8qQkYA91MEvK8d67Du+1ZeeW'
    'SY3kOqzck75DmedVIJfOafac19a+HPFG16svsSe/a/Q5UB5yE12q2VOFpSSU5G33M5PnUEXdutcKdV+F1x3/ANu6nUUrqWZszBch'
    'Op6gxStkbuET8SeLGnuKut9OPaWj3UMWiNMMqRMjllOXuzCQnff5B+io5mRjHOfnOcVEJXhIAwADnHh9tfF5XjT8RqH1kxmcLEpa'
    'uqdVPMkm6NtC8S4fDPX026XqDMk2S6w2WX5ENvtFxXWVuFClI/BIdVkjJ2G1JcTePNk1FxB0nqThlZJM652KUuZLlSoxjh+OWy2Y'
    '/MdzzBajv0IBFB6JCwD66vDr/bNN3VFR78Zzjzq/TYzNDAKe2gVyDF5oohCLWCvaR8JjgnfrEwnUlonvOtqDibbPtHpC23QPvdik'
    'nOQFZHWlLZ8K7SQhSE6i0lf7OoOKEJpqN24dYwOTOMBCyOqOg8TVCtkhYXgc34RAJp6mSAkDOMVbfxLUXuGi6sy8RVG+mvkoW4Xt'
    'p+0vTY0Zdqmyri/PtcBCSVxz2/aMJAA2weUDoK3FO1KmycNndU6ja9DEW3CbLZVjLZDfMpv25299Zj4Y8X9KcM7hfmNWWm5pdnvt'
    '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';

const String kPausedPanelB64 =
    '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';

const String kGameoverPanelB64 =
    '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'
    'wGQbwY9HobkNgiC//9k=';

/// Decoded panel artwork widget.
Widget panelImage(String b64) {
  return Image.memory(base64Decode(b64), fit: BoxFit.fill);
}

/// How-to dialog shared by Home and the in-game help button, mirroring the
/// reference picture: a mini board, a piece above it with a down arrow, the
/// steps, and a green Got-it button.
Future<void> showHowToDialog(BuildContext context) {
  // Fixed mini-board pattern: (row, col, color).
  const pattern = [
    (0, 0, 0xFFFFC107),
    (0, 2, 0xFF8E24AA),
    (1, 1, 0xFF1E88E5),
    (1, 3, 0xFF43A047),
    (2, 0, 0xFFEC407A),
    (2, 2, 0xFF00ACC1),
    (3, 1, 0xFFFFC107),
    (3, 3, 0xFFE53935),
  ];
  Widget cell(int r, int c) {
    Color? fill;
    for (final p in pattern) {
      if (p.$1 == r && p.$2 == c) fill = Color(p.$3);
    }
    return Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: fill ?? const Color(0xFFF5EFE3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  return showSheet(
    context,
    'How to Play',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 15,
                height: 30,
                decoration: BoxDecoration(color: const Color(0xFF8E24AA), borderRadius: BorderRadius.circular(4)),
              ),
              const Icon(Icons.arrow_downward, color: Color(0xFF1E88E5), size: 26),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: const Color(0xFF8D6E63), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (r) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(4, (c) => cell(r, c)))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('1. Drag the block to the board.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        const Text('2. Fill all the spaces to clear.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        const Text('3. Clear lines on consecutive moves to build combos.', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        const Text('4. The game ends when no remaining block fits anywhere. Beat your best score!', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        const Text('Tip: touch a block and it lifts up at once — the shadow shows exactly where it will land.',
            style: TextStyle(fontSize: 15, color: Colors.brown)),
        const SizedBox(height: 16),
        bigButton('Got it', const Color(0xFF43A047), () => Navigator.of(context).pop()),
      ],
    ),
  );
}

Widget miniBlocks(List<Color> colors) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: colors.take(4).map((c) {
      return Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: const Offset(0, 1))],
        ),
      );
    }).toList(),
  );
}

/// Glossy gradient button, like the picture's green Play / blue Restart.
Widget bigButton(String label, Color color, VoidCallback onTap, {IconData? icon}) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Sfx.play('click');
          onTap();
        },
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(color, Colors.white, 0.25)!,
                color,
                Color.lerp(color, Colors.black, 0.12)!,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showSheet(BuildContext context, String title, Widget body) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFFF8E7),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            woodHeader(title, onClose: () => Navigator.of(context).pop()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: body,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Settings dialog shared by Home and the in-game Pause dialog, styled like
/// the reference picture: Sound / Music / Vibrate toggles, Graphics Quality
/// Low / Medium / High, Language, Privacy Policy, Terms of Service.
Future<void> showSettingsDialog(BuildContext context, VoidCallback onChanged) {
  return showSheet(
    context,
    'Settings',
    StatefulBuilder(
      builder: (ctx, setDlg) {
        void refresh() {
          setDlg(() {});
          onChanged();
          profile.save();
        }

        Widget toggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged2) {
          return SwitchListTile(
            title: Row(children: [Icon(icon, color: const Color(0xFF8D6E63)), const SizedBox(width: 8), Text(label)]),
            value: value,
            activeColor: const Color(0xFF43A047),
            onChanged: (v) {
              onChanged2(v);
              refresh();
            },
          );
        }

        Widget qualityBtn(int v, String label) {
          final selected = profile.graphics == v;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ElevatedButton(
                onPressed: () {
                  profile.graphics = v;
                  Sfx.play('click');
                  refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? const Color(0xFF43A047) : const Color(0xFFD7CCC8),
                ),
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            toggle('Sound', Icons.volume_up, profile.sound, (v) {
              profile.sound = v;
              Sfx.enabled = v;
            }),
            toggle('Music', Icons.music_note, profile.music, (v) async {
              profile.music = v;
              Sfx.musicEnabled = v;
              if (v) {
                await Sfx.startMusic();
              } else {
                await Sfx.stopMusic();
              }
            }),
            toggle('Vibrate', Icons.vibration, profile.vibrate, (v) => profile.vibrate = v),
            const SizedBox(height: 8),
            const Text('Graphics Quality', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [qualityBtn(0, 'Low'), qualityBtn(1, 'Medium'), qualityBtn(2, 'High')]),
            const ListTile(title: Text('Language'), trailing: Text('English')),
            const ListTile(title: Text('Privacy Policy'), trailing: Icon(Icons.chevron_right)),
            const ListTile(title: Text('Terms of Service'), trailing: Icon(Icons.chevron_right)),
          ],
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Home IS the user's picture: the real home panel as the background,
    // with live tap zones sitting exactly on the painted buttons and a
    // live coin pill covering the painted "1250" pill.
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: panelImage(kHomePanelB64),
          ),
          // Live coin pill over the painted pill (fractions grounded on
          // the panel: (0.030,0.025)-(0.400,0.085)).
          Positioned(
            left: w * 0.030,
            top: h * 0.025,
            width: w * 0.370,
            height: h * 0.060,
            child: Container(
              decoration: BoxDecoration(
                color: kCream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kWood, width: 1.5),
              ),
              padding: const EdgeInsets.only(left: 8, right: 4, top: 2, bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Color(0xFFFFB300), size: 20),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${profile.coins}',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  InkWell(
                    onTap: () => _shop(context),
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _zone(w, h, 0.686, 0.024, 0.814, 0.093, () => _daily(context)),
          _zone(w, h, 0.844, 0.024, 0.966, 0.093, () => _settings(context)),
          _zone(w, h, 0.146, 0.644, 0.867, 0.778, () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen())).then((_) => setState(() {}));
          }),
          _zone(w, h, 0.048, 0.838, 0.264, 0.955, () => _daily(context)),
          _zone(w, h, 0.286, 0.838, 0.501, 0.955, () => _shop(context)),
          _zone(w, h, 0.517, 0.838, 0.729, 0.955, () => _achievements(context)),
          _zone(w, h, 0.755, 0.838, 0.963, 0.955, () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('More games coming soon!')));
          }),
        ],
      ),
    );
  }

  void _settings(BuildContext context) {
    showSettingsDialog(context, () => setState(() {}));
  }

  void _shop(BuildContext context) {
    var tab = 0;
    showSheet(
      context,
      'Shop',
      StatefulBuilder(
        builder: (ctx, setDlg) {
          Widget tabBtn(int i, String label) {
            final selected = tab == i;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ElevatedButton(
                  onPressed: () {
                    tab = i;
                    Sfx.play('click');
                    setDlg(() {});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: selected ? const Color(0xFF8D6E63) : const Color(0xFFD7CCC8)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }

          return Column(
            children: [
              Row(children: [coinChip(), const Spacer()]),
              const SizedBox(height: 12),
              Row(children: [tabBtn(0, 'Blocks'), tabBtn(1, 'Themes'), tabBtn(2, 'Coins')]),
              const SizedBox(height: 12),
              if (tab == 0) ...kBlockThemes.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                final owned = profile.ownedThemes.contains(i);
                final equipped = profile.theme == i;
                return Card(
                  child: ListTile(
                    leading: miniBlocks(t.colors),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(equipped ? 'Equipped' : (owned ? 'Owned' : '${t.price} coins')),
                    trailing: ElevatedButton(
                      onPressed: () {
                        if (equipped) return;
                        if (!owned) {
                          if (profile.coins < t.price) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Not enough coins yet — clear more lines!')));
                            return;
                          }
                          profile.coins -= t.price;
                          profile.ownedThemes.add(i);
                          Sfx.play('coin');
                        }
                        profile.theme = i;
                        profile.save();
                        setDlg(() {});
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: equipped ? const Color(0xFF43A047) : const Color(0xFFFFB300)),
                      child: Text(equipped ? '✓' : (owned ? 'Equip' : '${t.price}'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
              if (tab == 1) ...kBoardThemes.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                final equipped = profile.boardTheme == i;
                return Card(
                  child: ListTile(
                    leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: t.cell, border: Border.all(color: t.frame, width: 3), borderRadius: BorderRadius.circular(8))),
                    title: Text(t.name),
                    trailing: ElevatedButton(
                      onPressed: () {
                        profile.boardTheme = i;
                        profile.save();
                        setDlg(() {});
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: equipped ? const Color(0xFF43A047) : const Color(0xFF8D6E63)),
                      child: Text(equipped ? '✓' : 'Use', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                );
              }),
              if (tab == 2)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You have ${profile.coins} coins.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Earn coins by clearing lines, combos and the Daily Challenge. No purchase needed.',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    bigButton('Go to Daily Challenge', const Color(0xFFFFB300), () {
                      Navigator.of(ctx).pop();
                      _daily(context);
                    }),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  void _daily(BuildContext context) {
    const goal = 20;
    final done = profile.dailyLines >= goal;
    showSheet(
      context,
      'Daily Challenge',
      StatefulBuilder(
        builder: (ctx, setDlg) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Clear 20 lines today and get rewards!'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 7; i++)
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: i < profile.streakDays.clamp(0, 7) ? const Color(0xFF43A047) : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: i < profile.streakDays.clamp(0, 7)
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : const SizedBox.shrink(),
                    ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(color: Color(0xFFFFB300), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: const Color(0xFF8D6E63), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(8, (r) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(8, (c) {
                          const filled = {
                            (0, 1): 0xFFFFC107,
                            (1, 1): 0xFF8E24AA,
                            (1, 4): 0xFF1E88E5,
                            (2, 2): 0xFF43A047,
                            (3, 0): 0xFFEC407A,
                            (3, 5): 0xFF00ACC1,
                            (4, 3): 0xFFFFC107,
                            (5, 6): 0xFFE53935,
                          };
                          final v = filled[(r, c)];
                          return Container(
                            width: 11,
                            height: 11,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: v == null ? const Color(0xFFF5EFE3) : Color(v),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (profile.dailyLines / goal).clamp(0.0, 1.0),
                backgroundColor: Colors.brown.shade100,
                color: const Color(0xFF43A047),
                minHeight: 10,
              ),
              const SizedBox(height: 8),
              Text('${profile.dailyLines} / $goal lines'),
              const SizedBox(height: 16),
              bigButton(
                profile.dailyClaimed ? 'Claimed ✓' : (done ? 'Claim 100 coins' : 'Play'),
                done && !profile.dailyClaimed ? const Color(0xFFFFB300) : const Color(0xFF43A047),
                () {
                  if (done && !profile.dailyClaimed) {
                    profile.coins += 100;
                    profile.dailyClaimed = true;
                    profile.save();
                    Sfx.play('coin');
                    setDlg(() {});
                    setState(() {});
                  } else {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen())).then((_) => setState(() {}));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _achievements(BuildContext context) {
    // Mirrors the picture's list, adapted to endless play (no levels):
    // First Move / 10 Games / Block Master / Perfect Clear / Daily Player.
    final defs = <(String, String, int Function(), int, int)>[
      ('First Move', 'Place your first block', () => profile.gamesPlayed > 0 ? 1 : 0, 1, 50),
      ('10 Games', 'Play 10 games', () => profile.gamesPlayed, 10, 100),
      ('Block Master', 'Clear 1000 blocks in total', () => profile.totalCleared, 1000, 200),
      ('Perfect Clear', 'Clear 3 lines in one move', () => profile.maxLinesInMove, 3, 150),
      ('Daily Player', 'Play 7 days in a row', () => profile.streakDays, 7, 200),
    ];
    showSheet(
      context,
      'Achievements',
      StatefulBuilder(
        builder: (ctx, setDlg) {
          return Column(
            children: defs.map((d) {
              final cur = d.$3();
              final complete = cur >= d.$4;
              final claimed = profile.claimedAchievements.contains(d.$1);
              return Card(
                child: ListTile(
                  leading: Icon(complete ? Icons.emoji_events : Icons.star_border, color: complete ? const Color(0xFFFFB300) : Colors.grey),
                  title: Text(d.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.$2),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: (cur / d.$4).clamp(0.0, 1.0), color: const Color(0xFF43A047), backgroundColor: Colors.brown.shade100),
                      Text('$cur / ${d.$4}'),
                    ],
                  ),
                  trailing: claimed
                      ? const Text('✓', style: TextStyle(fontSize: 20, color: Color(0xFF43A047)))
                      : (complete
                          ? ElevatedButton(
                              onPressed: () {
                                profile.coins += d.$5;
                                profile.claimedAchievements.add(d.$1);
                                profile.save();
                                Sfx.play('coin');
                                setDlg(() {});
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB300)),
                              child: Text('+${d.$5}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            )
                          : null),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _howTo(BuildContext context) {
    showHowToDialog(context);
  }
}

// ---------------------------------------------------------------------------
// Game
// ---------------------------------------------------------------------------

class _Snapshot {
  final List<List<int>> board;
  final List<Piece?> tray;
  final int score;
  final int runCoins;
  final int combo;
  _Snapshot(this.board, this.tray, this.score, this.runCoins, this.combo);
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random _rng = Random();
  final GlobalKey _boardKey = GlobalKey();
  int _pieceSeq = 0;

  List<List<int>> _board = List.generate(kBoard, (_) => List.filled(kBoard, -1));
  List<Piece?> _tray = [null, null, null];
  int _score = 0;
  int _runCoins = 0;
  int _combo = 0;
  int _shuffleLeft = 3;
  int _hintLeft = 5;
  int _undoLeft = 3;
  final List<_Snapshot> _undoStack = [];

  Set<int> _clearingRows = {};
  Set<int> _clearingCols = {};
  bool _clearing = false;

  int? _draggingIdx;
  Offset _dragPos = Offset.zero;
  int _hoverRow = -1;
  int _hoverCol = -1;
  bool _hoverValid = false;
  Offset _boardOrigin = Offset.zero;
  double _cellSize = 32;

  ({int piece, int row, int col})? _hintGhost;
  String _lastGain = '';
  int _lastGainId = 0;
  bool _gameOverShown = false;
  bool _newBest = false;

  List<Color> get _colors => kBlockThemes[profile.theme].colors;
  BoardTheme get _bTheme => kBoardThemes[profile.boardTheme];

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _vibrate() {
    if (profile.vibrate) HapticFeedback.lightImpact();
  }

  void _newGame() {
    _board = List.generate(kBoard, (_) => List.filled(kBoard, -1));
    _score = 0;
    _runCoins = 0;
    _combo = 0;
    _shuffleLeft = 3;
    _hintLeft = 5;
    _undoLeft = 3;
    _undoStack.clear();
    _clearingRows = {};
    _clearingCols = {};
    _clearing = false;
    _draggingIdx = null;
    _hintGhost = null;
    _gameOverShown = false;
    _newBest = false;
    profile.gamesPlayed++;
    profile.markPlayedToday();
    profile.save();
    _prefillBoard();
    _dealTray(ensureMove: true);
  }

  /// The game starts with random blocks already on the board, like the
  /// reference picture's gameplay panel — never an empty board.
  void _prefillBoard() {
    const targetCells = 20; // ~31% of the 64 cells.
    var placed = 0;
    var attempts = 0;
    while (placed < targetCells && attempts < 200) {
      attempts++;
      final p = Piece(randomShape(_rng), _rng.nextInt(_colors.length), 'pre');
      final r = _rng.nextInt(kBoard);
      final c = _rng.nextInt(kBoard);
      if (!_canPlace(p, r, c)) continue;
      final comp = _wouldComplete(p, r, c);
      if (comp.rows.isNotEmpty || comp.cols.isNotEmpty) continue;
      for (final cell in p.shape.cells) {
        _board[r + cell.x][c + cell.y] = p.color;
      }
      placed += p.shape.size;
    }
  }

  void _dealTray({bool ensureMove = false}) {
    setState(() {
      var tries = 0;
      do {
        _tray = List.generate(3, (_) {
          final shape = randomShape(_rng);
          return Piece(shape, _rng.nextInt(_colors.length), 'p${_pieceSeq++}');
        });
        tries++;
      } while (ensureMove && !_anyMove() && tries < 50);
      if (ensureMove && !_anyMove()) {
        // Vanishingly unlikely at ~31% fill, but a game must never start
        // dead: clear a few random filled cells and deal once more.
        var cleared = 0;
        var guard = 0;
        while (cleared < 10 && guard < 200) {
          guard++;
          final r = _rng.nextInt(kBoard);
          final c = _rng.nextInt(kBoard);
          if (_board[r][c] != -1) {
            _board[r][c] = -1;
            cleared++;
          }
        }
        _tray = List.generate(3, (_) {
          final shape = randomShape(_rng);
          return Piece(shape, _rng.nextInt(_colors.length), 'p${_pieceSeq++}');
        });
      }
    });
  }

  bool _canPlace(Piece p, int r, int c) {
    for (final cell in p.shape.cells) {
      final rr = r + cell.x;
      final cc = c + cell.y;
      if (rr < 0 || rr >= kBoard || cc < 0 || cc >= kBoard) return false;
      if (_board[rr][cc] != -1) return false;
    }
    return true;
  }

  bool _fitsAnywhere(Piece p) {
    for (var r = 0; r < kBoard; r++) {
      for (var c = 0; c < kBoard; c++) {
        if (_canPlace(p, r, c)) return true;
      }
    }
    return false;
  }

  bool _anyMove() => _tray.any((p) => p != null && _fitsAnywhere(p));

  ({Set<int> rows, Set<int> cols}) _wouldComplete(Piece p, int r, int c) {
    final rows = <int>{};
    final cols = <int>{};
    // Simulate on a copy.
    final sim = _board.map((row) => List<int>.from(row)).toList();
    for (final cell in p.shape.cells) {
      sim[r + cell.x][c + cell.y] = p.color;
    }
    for (var rr = 0; rr < kBoard; rr++) {
      if (sim[rr].every((v) => v != -1)) rows.add(rr);
    }
    for (var cc = 0; cc < kBoard; cc++) {
      var full = true;
      for (var rr = 0; rr < kBoard; rr++) {
        if (sim[rr][cc] == -1) full = false;
      }
      if (full) cols.add(cc);
    }
    return (rows: rows, cols: cols);
  }

  void _showGain(String text) {
    final id = ++_lastGainId;
    setState(() => _lastGain = text);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && id == _lastGainId) setState(() => _lastGain = '');
    });
  }

  void _placePiece(int idx, int r, int c) {
    final p = _tray[idx];
    if (p == null || !_canPlace(p, r, c)) return;
    _undoStack.add(_Snapshot(
      _board.map((row) => List<int>.from(row)).toList(),
      List<Piece?>.from(_tray),
      _score,
      _runCoins,
      _combo,
    ));
    setState(() {
      for (final cell in p.shape.cells) {
        _board[r + cell.x][c + cell.y] = p.color;
      }
      _tray[idx] = null;
      _score += p.shape.size * 10;
      _draggingIdx = null;
      _hintGhost = null;
    });
    Sfx.play('place');
    _vibrate();

    // Full rows / columns on the board after this placement.
    final rows = <int>{};
    final cols = <int>{};
    for (var rr = 0; rr < kBoard; rr++) {
      if (_board[rr].every((v) => v != -1)) rows.add(rr);
    }
    for (var cc = 0; cc < kBoard; cc++) {
      var full = true;
      for (var rr = 0; rr < kBoard; rr++) {
        if (_board[rr][cc] == -1) full = false;
      }
      if (full) cols.add(cc);
    }
    if (rows.isNotEmpty || cols.isNotEmpty) {
      final lines = rows.length + cols.length;
      _combo += 1;
      if (_combo > profile.bestCombo) profile.bestCombo = _combo;
      var gain = lines == 1 ? 100 : (lines == 2 ? 300 : (lines == 3 ? 600 : 1000));
      if (_combo >= 2) gain += (_combo - 1) * 50;
      final coins = lines * 10 + (_combo >= 2 ? 20 : 0);
      setState(() {
        _clearingRows = rows;
        _clearingCols = cols;
        _clearing = true;
        _score += gain;
        _runCoins += coins;
        profile.coins += coins;
        profile.totalCleared += rows.length * kBoard + cols.length * kBoard;
        if (lines > profile.maxLinesInMove) profile.maxLinesInMove = lines;
        profile.dailyLines += lines;
      });
      if (_combo >= 2) {
        Sfx.play('combo');
        _showGain('COMBO x$_combo  +$gain');
      } else {
        Sfx.play('clear');
        _showGain('+$gain');
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          for (final rr in _clearingRows) {
            for (var cc = 0; cc < kBoard; cc++) _board[rr][cc] = -1;
          }
          for (final cc in _clearingCols) {
            for (var rr = 0; rr < kBoard; rr++) _board[rr][cc] = -1;
          }
          _clearingRows = {};
          _clearingCols = {};
          _clearing = false;
        });
        profile.save();
        _afterMove();
      });
    } else {
      _combo = 0;
      _afterMove();
    }
  }

  void _afterMove() {
    if (_tray.every((p) => p == null)) _dealTray();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _gameOverShown) return;
      if (!_anyMove()) _gameOver();
    });
  }

  void _gameOver() {
    _gameOverShown = true;
    Sfx.play('gameover');
    _newBest = _score > profile.best;
    if (_newBest) profile.best = _score;
    profile.save();
    // Game Over IS the user's picture: the real completed panel as the
    // dialog, with a "Game Over" ribbon and live stats covering the
    // painted "Level 12" ribbon and stats, and taps on the painted
    // buttons (fractions grounded on the panel).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final sw = MediaQuery.of(ctx).size.width;
        final sh = MediaQuery.of(ctx).size.height;
        var w = sw * 0.88;
        var h = w / 0.703;
        if (h > sh * 0.92) {
          h = sh * 0.92;
          w = h * 0.703;
        }
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: panelImage(kGameoverPanelB64),
                ),
                Positioned(
                  left: w * 0.090,
                  top: h * 0.210,
                  width: w * 0.820,
                  height: h * 0.175,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Game Over', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
                Positioned(
                  left: w * 0.118,
                  top: h * 0.405,
                  width: w * 0.764,
                  height: h * 0.240,
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_newBest) const Text('NEW BEST!', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF8F00))),
                        Text('Score    $_score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Best    ${profile.best}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Coins earned    $_runCoins', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                _zone(w, h, 0.118, 0.668, 0.882, 0.798, () {
                  Navigator.of(ctx).pop();
                  setState(_newGame);
                }),
                _zone(w, h, 0.238, 0.818, 0.762, 0.925, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- drag ---------------------------------------------------------------

  void _boardMetrics() {
    final ctx = _boardKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    // Board container has 6px padding and the grid has 2px gaps: the pitch
    // between cell origins is (width - padding) / kBoard, and cell (0,0)
    // starts at the container origin + padding. Using the pitch (not the
    // visual cell size) keeps the ghost aligned across the board.
    _boardOrigin = box.localToGlobal(const Offset(6, 6));
    _cellSize = (box.size.width - 12) / kBoard;
  }

  void _updateHover(Offset global) {
    final idx = _draggingIdx;
    if (idx == null) return;
    final p = _tray[idx];
    if (p == null) return;
    final gx = (global.dx - _boardOrigin.dx) / _cellSize;
    final gy = (global.dy - _boardOrigin.dy) / _cellSize;
    final r = (gy - (p.shape.height - 1) / 2).round();
    final c = (gx - (p.shape.width - 1) / 2).round();
    setState(() {
      _hoverRow = r;
      _hoverCol = c;
      _hoverValid = _canPlace(p, r, c);
    });
  }

  // Lift the piece the instant the finger TOUCHES it (onPanDown), not only
  // once the finger starts moving (onPanStart fires after the move slop, so
  // a touch-and-hold showed nothing in build 1 — the user's complaint).
  /// Screen position of the CENTER of the lifted piece. The piece floats
  /// above the finger, so the ghost must follow the piece — never the
  /// finger (in 1.0.3 the ghost sat under the finger while the piece
  /// floated above it, which looked broken).
  Offset _pieceCenter(Offset finger, int idx) {
    final p = _tray[idx];
    if (p == null) return finger;
    final cell = p.shape.width >= 4 || p.shape.height >= 4 ? 15.0 : 19.0;
    final ph = p.shape.height * cell;
    return Offset(finger.dx, finger.dy - 90 - ph / 2);
  }

  void _dragStart(int idx, Offset globalPos) {
    if (_clearing) return;
    _boardMetrics();
    setState(() {
      _draggingIdx = idx;
      _dragPos = globalPos;
      _hintGhost = null;
    });
    Sfx.play('pickup');
    _vibrate();
    _updateHover(_pieceCenter(globalPos, idx));
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_draggingIdx == null) return;
    setState(() => _dragPos = d.globalPosition);
    _updateHover(_pieceCenter(d.globalPosition, _draggingIdx!));
  }

  void _dragEnd() {
    final idx = _draggingIdx;
    if (idx == null) return;
    if (_hoverValid && _hoverRow >= 0 && _hoverCol >= 0) {
      _placePiece(idx, _hoverRow, _hoverCol);
    } else {
      Sfx.play('invalid');
      setState(() {
        _draggingIdx = null;
        _hoverRow = -1;
        _hoverCol = -1;
      });
    }
  }

  // -- boosters -------------------------------------------------------------

  void _shuffle() {
    if (_shuffleLeft <= 0 || _tray.every((p) => p == null)) return;
    setState(() {
      _shuffleLeft--;
      for (var i = 0; i < 3; i++) {
        if (_tray[i] != null) {
          final shape = randomShape(_rng);
          _tray[i] = Piece(shape, _rng.nextInt(_colors.length), 'p${_pieceSeq++}');
        }
      }
    });
    Sfx.play('shuffle');
  }

  void _hint() {
    if (_hintLeft <= 0) return;
    var bestScore = -1;
    ({int piece, int row, int col})? best;
    for (var i = 0; i < 3; i++) {
      final p = _tray[i];
      if (p == null) continue;
      for (var r = 0; r < kBoard; r++) {
        for (var c = 0; c < kBoard; c++) {
          if (!_canPlace(p, r, c)) continue;
          final comp = _wouldComplete(p, r, c);
          var contacts = 0;
          for (final cell in p.shape.cells) {
            final rr = r + cell.x;
            final cc = c + cell.y;
            if (rr > 0 && _board[rr - 1][cc] != -1) contacts++;
            if (rr < kBoard - 1 && _board[rr + 1][cc] != -1) contacts++;
            if (cc > 0 && _board[rr][cc - 1] != -1) contacts++;
            if (cc < kBoard - 1 && _board[rr][cc + 1] != -1) contacts++;
          }
          final s = (comp.rows.length + comp.cols.length) * 100 + contacts * 2;
          if (s > bestScore) {
            bestScore = s;
            best = (piece: i, row: r, col: c);
          }
        }
      }
    }
    if (best == null) return;
    setState(() {
      _hintLeft--;
      _hintGhost = best;
    });
    Sfx.play('click');
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _hintGhost = null);
    });
  }

  void _undo() {
    if (_undoLeft <= 0 || _undoStack.isEmpty) return;
    final s = _undoStack.removeLast();
    setState(() {
      _board = s.board.map((row) => List<int>.from(row)).toList();
      _tray = List<Piece?>.from(s.tray);
      _score = s.score;
      _runCoins = s.runCoins;
      _combo = s.combo;
      _undoLeft--;
      _hintGhost = null;
    });
    Sfx.play('click');
  }

  void _pauseDialog() {
    // Paused IS the user's picture: the real paused panel as the dialog,
    // with tap zones exactly on the painted buttons (fractions grounded
    // on the panel). The panel already contains the dimmed game, so the
    // barrier itself stays transparent.
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final sw = MediaQuery.of(ctx).size.width;
        final sh = MediaQuery.of(ctx).size.height;
        var w = sw * 0.92;
        var h = w / 0.645;
        if (h > sh * 0.92) {
          h = sh * 0.92;
          w = h * 0.645;
        }
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: panelImage(kPausedPanelB64),
                ),
                _zone(w, h, 0.783, 0.213, 0.886, 0.282, () => Navigator.of(ctx).pop()),
                _zone(w, h, 0.227, 0.347, 0.789, 0.449, () => Navigator.of(ctx).pop()),
                _zone(w, h, 0.227, 0.470, 0.789, 0.572, () {
                  Navigator.of(ctx).pop();
                  setState(_newGame);
                }),
                _zone(w, h, 0.227, 0.591, 0.789, 0.688, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                }),
                _zone(w, h, 0.227, 0.697, 0.789, 0.791, () {
                  showSettingsDialog(context, () => setState(() {}));
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- rendering --------------------------------------------------------------

  /// Boxed Score/Best readout in the picture's top-bar style.
  Widget _topBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFDEBD0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8D6E63), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _pieceWidget(Piece p, double cell, {bool withShadow = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: p.shape.rows.map((rowStr) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: rowStr.split('').map((ch) {
            if (ch != '1') return SizedBox(width: cell, height: cell);
            return Container(
              width: cell,
              height: cell,
              margin: EdgeInsets.all(max(1.0, cell * 0.04)),
              decoration: BoxDecoration(
                gradient: glossGradient(_colors[p.color % _colors.length]),
                borderRadius: BorderRadius.circular(cell * 0.18),
                // Graphics Quality Low disables shadows entirely.
                boxShadow: profile.graphics == 0
                    ? null
                    : (withShadow
                        ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 6))]
                        : [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 2, offset: const Offset(0, 1))]),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Set<Point<int>> _ghostCells() {
    final out = <Point<int>>{};
    Piece? p;
    int? r, c;
    if (_draggingIdx != null) {
      // Show the shadow even on an invalid hover (tinted red in the board),
      // so the player sees exactly why it does not fit.
      p = _tray[_draggingIdx!];
      r = _hoverRow;
      c = _hoverCol;
    } else if (_hintGhost != null) {
      p = _tray[_hintGhost!.piece];
      r = _hintGhost!.row;
      c = _hintGhost!.col;
    }
    if (p != null && r != null && c != null) {
      for (final cell in p.shape.cells) {
        final rr = r + cell.x;
        final cc = c + cell.y;
        if (rr >= 0 && rr < kBoard && cc >= 0 && cc < kBoard) {
          out.add(Point(rr, cc));
        }
      }
    }
    return out;
  }

  bool get _ghostInvalid => _draggingIdx != null && !_hoverValid;

  ({Set<int> rows, Set<int> cols}) _previewLines() {
    if (_draggingIdx != null && _hoverValid) {
      final p = _tray[_draggingIdx!];
      if (p != null) return _wouldComplete(p, _hoverRow, _hoverCol);
    }
    return (rows: <int>{}, cols: <int>{});
  }

  Widget _buildBoard(double size) {
    final ghost = _ghostCells();
    final preview = _previewLines();
    final dragPiece = _draggingIdx != null ? _tray[_draggingIdx!] : null;
    final ghostColor = dragPiece != null ? _colors[dragPiece.color % _colors.length] : (_hintGhost != null && _tray[_hintGhost!.piece] != null ? _colors[_tray[_hintGhost!.piece]!.color % _colors.length] : Colors.grey);
    return Container(
      key: _boardKey,
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: woodGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWoodDark, width: 2),
        boxShadow: profile.graphics == 0
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: kBoard,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: kBoard * kBoard,
        itemBuilder: (_, i) {
          final r = i ~/ kBoard;
          final c = i % kBoard;
          final v = _board[r][c];
          final isClearing = _clearingRows.contains(r) || _clearingCols.contains(c);
          final isGhost = ghost.contains(Point(r, c));
          final isPreviewLine = preview.rows.contains(r) || preview.cols.contains(c);
          Color bg;
          if (v != -1) {
            bg = _colors[v % _colors.length];
          } else if (isGhost) {
            bg = _ghostInvalid ? Colors.red.withOpacity(0.30) : ghostColor.withOpacity(0.45);
          } else if (isPreviewLine) {
            bg = Color.alphaBlend(Colors.white.withOpacity(0.35), _bTheme.cell);
          } else {
            bg = _bTheme.cell;
          }
          final filled = v != -1;
          return AnimatedScale(
            scale: isClearing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 260),
            child: Container(
              decoration: BoxDecoration(
                color: filled ? null : bg,
                gradient: filled ? glossGradient(_colors[v % _colors.length]) : null,
                borderRadius: BorderRadius.circular(5),
                border: isGhost
                    ? Border.all(color: _ghostInvalid ? Colors.red : ghostColor, width: 1.5)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _booster(IconData icon, String label, int left, VoidCallback onTap) {
    final disabled = left <= 0;
    // Picture colors: Shuffle orange, Hint blue, Undo green.
    final c = label == 'Shuffle'
        ? const Color(0xFFFF8F00)
        : (label == 'Hint' ? const Color(0xFF1E88E5) : const Color(0xFF43A047));
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(32),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color.lerp(c, Colors.white, 0.25)!, c],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('$left', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5D4037))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dragPiece = _draggingIdx != null ? _tray[_draggingIdx!] : null;
    return Scaffold(
      backgroundColor: _bTheme.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.pause, color: Colors.white),
                          onPressed: _pauseDialog,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Center(child: _topBox('SCORE', '$_score'))),
                      const SizedBox(width: 8),
                      _topBox('BEST', '${max(profile.best, _score)}'),
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Color(0xFF8D6E63)),
                        onPressed: () => showHowToDialog(context),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 26,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_combo >= 2)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFFF6D00), borderRadius: BorderRadius.circular(14)),
                            child: Text('COMBO x$_combo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        if (_lastGain.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(_lastGain, style: const TextStyle(color: Color(0xFF43A047), fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final size = min(constraints.maxWidth, constraints.maxHeight);
                        return Center(child: _buildBoard(size));
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Tray: exactly 3 random blocks.
                  SizedBox(
                    height: 104,
                    child: Row(
                      children: List.generate(3, (i) {
                        final piece = _tray[i];
                        final isDraggingThis = _draggingIdx == i;
                        return Expanded(
                          child: Center(
                            child: piece == null
                                ? const SizedBox(height: 60)
                                : Opacity(
                                    // Fully hidden while dragging — no leftover
                                    // copy under the finger (user report).
                                    opacity: isDraggingThis ? 0.0 : 1.0,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanDown: (d) => _dragStart(i, d.globalPosition),
                                      onPanUpdate: _dragUpdate,
                                      onPanEnd: (_) => _dragEnd(),
                                      onPanCancel: () => setState(() {
                                        _draggingIdx = null;
                                        _hoverRow = -1;
                                        _hoverCol = -1;
                                      }),
                                      child: TweenAnimationBuilder<double>(
                                        key: ValueKey(piece.id),
                                        tween: Tween(begin: 0.5, end: 1.0),
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeOutBack,
                                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                                        child: _pieceWidget(piece, piece.shape.width >= 4 || piece.shape.height >= 4 ? 15 : 19),
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _booster(Icons.shuffle, 'Shuffle', _shuffleLeft, _shuffle),
                      _booster(Icons.lightbulb, 'Hint', _hintLeft, _hint),
                      _booster(Icons.undo, 'Undo', _undoLeft, _undo),
                      // Fourth slot, plain brown like the picture's empty tile.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              gradient: woodGradient(),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(' ', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Dragged piece floats ABOVE the finger, at exactly the SAME
            // size as the tray original (never bigger — user report), with
            // its bottom edge 90px above the touch point. The ghost follows
            // this lifted piece via _pieceCenter, so piece and shadow move
            // as one clean unit.
            if (dragPiece != null)
              Builder(
                builder: (ctx) {
                  final cell = dragPiece.shape.width >= 4 || dragPiece.shape.height >= 4 ? 15.0 : 19.0;
                  final pw = dragPiece.shape.width * cell;
                  final ph = dragPiece.shape.height * cell;
                  final sw = MediaQuery.of(ctx).size.width;
                  // clamp() returns num, but Positioned needs double — cast.
                  final left = (_dragPos.dx - pw / 2).clamp(8.0, max(8.0, sw - pw - 8)).toDouble();
                  final top = max(8.0, _dragPos.dy - ph - 90).toDouble();
                  return Positioned(
                    left: left,
                    top: top,
                    child: IgnorePointer(
                      child: _pieceWidget(dragPiece, cell, withShadow: true),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
