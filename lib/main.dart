// Block Puzzle v2 — fresh rebuild, code-only, per the v2 UI panels.
// Endless 8x8 block puzzle. No ads. No pasted pictures, no generated art:
// every screen is constructed widgets (gradients, shapes, shadows).
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BlockPuzzleApp());
}

// ---------------- Sound ----------------
class Sfx {
  static final AudioPlayer _fx = AudioPlayer();
  static final AudioPlayer _music = AudioPlayer();
  static bool _musicOn = false;
  static bool _started = false;

  static Future<void> play(String name, bool soundOn) async {
    if (!soundOn) return;
    try {
      await _fx.stop();
      await _fx.play(AssetSource('sfx/$name.wav'));
    } catch (_) {}
  }

  static Future<void> startMusic(bool musicOn) async {
    _musicOn = musicOn;
    if (!musicOn) {
      try {
        await _music.stop();
      } catch (_) {}
      _started = false;
      return;
    }
    if (_started) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource('sfx/music.wav'));
      _started = true;
    } catch (_) {}
  }

  static Future<void> setMusic(bool on) async {
    _musicOn = on;
    if (on) {
      await startMusic(true);
    } else {
      try {
        await _music.stop();
      } catch (_) {}
      _started = false;
    }
  }
}

// ---------------- Profile (SharedPreferences) ----------------
class Profile {
  int coins = 1250;
  int best = 0;
  bool sound = true;
  bool music = true;
  bool vibrate = false;
  int graphics = 1; // 0 Low, 1 Medium, 2 High
  int blockTheme = 0; // 0 Default, 1 Wooden, 2 Neon, 3 Galaxy
  int boardTheme = 0; // 0 Garden, 1 Wood, 2 Night
  Set<int> ownedBlocks = {0};
  Set<int> ownedBoards = {0};
  int shuffles = 3;
  int hints = 5;
  int undos = 3;
  int games = 0;
  int cleared = 0;
  int maxLines = 0;
  int moves = 0;
  String dailyKey = '';
  int dailyLines = 0;
  int dailyStreak = 0;
  bool dailyClaimed = false;
  Set<String> claimedAch = {};

  static String todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      coins = p.getInt('coins') ?? 1250;
      best = p.getInt('best') ?? 0;
      sound = p.getBool('sound') ?? true;
      music = p.getBool('music') ?? true;
      vibrate = p.getBool('vibrate') ?? false;
      graphics = p.getInt('graphics') ?? 1;
      blockTheme = p.getInt('blockTheme') ?? 0;
      boardTheme = p.getInt('boardTheme') ?? 0;
      ownedBlocks = (p.getStringList('ownedBlocks') ?? ['0'])
          .map((e) => int.tryParse(e) ?? 0)
          .toSet();
      ownedBoards = (p.getStringList('ownedBoards') ?? ['0'])
          .map((e) => int.tryParse(e) ?? 0)
          .toSet();
      shuffles = p.getInt('shuffles') ?? 3;
      hints = p.getInt('hints') ?? 5;
      undos = p.getInt('undos') ?? 3;
      games = p.getInt('games') ?? 0;
      cleared = p.getInt('cleared') ?? 0;
      maxLines = p.getInt('maxLines') ?? 0;
      moves = p.getInt('moves') ?? 0;
      dailyKey = p.getString('dailyKey') ?? '';
      dailyLines = p.getInt('dailyLines') ?? 0;
      dailyStreak = p.getInt('dailyStreak') ?? 0;
      dailyClaimed = p.getBool('dailyClaimed') ?? false;
      claimedAch = (p.getStringList('claimedAch') ?? []).toSet();
      final tk = todayKey();
      if (dailyKey != tk) {
        final y = DateTime.now().subtract(const Duration(days: 1));
        final yk = '${y.year}-${y.month}-${y.day}';
        if (dailyKey != yk) dailyStreak = 0;
        dailyKey = tk;
        dailyLines = 0;
        dailyClaimed = false;
        await save();
      }
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      await p.setInt('coins', coins);
      await p.setInt('best', best);
      await p.setBool('sound', sound);
      await p.setBool('music', music);
      await p.setBool('vibrate', vibrate);
      await p.setInt('graphics', graphics);
      await p.setInt('blockTheme', blockTheme);
      await p.setInt('boardTheme', boardTheme);
      await p.setStringList(
          'ownedBlocks', ownedBlocks.map((e) => '$e').toList());
      await p.setStringList(
          'ownedBoards', ownedBoards.map((e) => '$e').toList());
      await p.setInt('shuffles', shuffles);
      await p.setInt('hints', hints);
      await p.setInt('undos', undos);
      await p.setInt('games', games);
      await p.setInt('cleared', cleared);
      await p.setInt('maxLines', maxLines);
      await p.setInt('moves', moves);
      await p.setString('dailyKey', dailyKey);
      await p.setInt('dailyLines', dailyLines);
      await p.setInt('dailyStreak', dailyStreak);
      await p.setBool('dailyClaimed', dailyClaimed);
      await p.setStringList('claimedAch', claimedAch.toList());
    } catch (_) {}
  }
}

final Profile profile = Profile();

// ---------------- Pieces ----------------
class Shape {
  final List<List<int>> cells; // [row, col]
  const Shape(this.cells);
  int get w => cells.map((c) => c[1]).reduce(math.max) + 1;
  int get h => cells.map((c) => c[0]).reduce(math.max) + 1;
}

const List<Shape> shapes = [
  Shape([[0, 0]]),
  Shape([[0, 0], [0, 1]]),
  Shape([[0, 0], [1, 0]]),
  Shape([[0, 0], [0, 1], [0, 2]]),
  Shape([[0, 0], [1, 0], [2, 0]]),
  Shape([[0, 0], [0, 1], [0, 2], [0, 3]]),
  Shape([[0, 0], [1, 0], [2, 0], [3, 0]]),
  Shape([[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]]),
  Shape([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]),
  Shape([[0, 0], [0, 1], [1, 0], [1, 1]]),
  Shape([[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]]),
  Shape([[0, 0], [0, 1], [1, 0]]),
  Shape([[0, 0], [0, 1], [1, 1]]),
  Shape([[0, 0], [1, 0], [1, 1]]),
  Shape([[0, 1], [1, 0], [1, 1]]),
  Shape([[0, 0], [0, 1], [0, 2], [1, 0]]),
  Shape([[0, 0], [0, 1], [0, 2], [1, 2]]),
  Shape([[0, 2], [1, 0], [1, 1], [1, 2]]),
  Shape([[0, 0], [1, 0], [1, 1], [1, 2]]),
  Shape([[0, 0], [0, 1], [1, 0], [1, 1], [1, 2]]),
  Shape([[0, 1], [1, 0], [1, 1], [1, 2]]),
  Shape([[0, 0], [0, 1], [0, 2], [1, 1]]),
  Shape([[0, 1], [1, 0], [1, 1], [1, 2], [2, 1]]),
  Shape([[0, 1], [0, 2], [1, 0], [1, 1]]),
  Shape([[0, 0], [0, 1], [1, 1], [1, 2]]),
];

class Piece {
  final Shape shape;
  final Color color;
  const Piece(this.shape, this.color);
}

Piece randomPiece(math.Random r) {
  final idx = r.nextInt(shapes.length);
  final palettes = blockPalettes[profile.blockTheme];
  return Piece(shapes[idx], palettes[r.nextInt(palettes.length)]);
}

// Block color palettes per theme (top, bottom for gloss gradient).
const List<List<Color>> blockPalettes = [
  [
    Color(0xFF4DA3FF),
    Color(0xFFFF5DA2),
    Color(0xFFFFC93C),
    Color(0xFF3ED598),
    Color(0xFF9B5DE5),
    Color(0xFFFF6B35),
  ],
  [
    Color(0xFFB07A45),
    Color(0xFF8A5A2B),
    Color(0xFFC68B4E),
    Color(0xFF7A4A22),
  ],
  [
    Color(0xFF00E5FF),
    Color(0xFFFF2E88),
    Color(0xFFB6FF00),
    Color(0xFF7C4DFF),
    Color(0xFFFFEA00),
  ],
  [
    Color(0xFF6A5ACD),
    Color(0xFF1E90FF),
    Color(0xFFBA55D3),
    Color(0xFF00CED1),
    Color(0xFF9370DB),
  ],
];

// ---------------- Shared visuals (all code-drawn) ----------------
List<BoxShadow> sh([Color c = const Color(0x40000000), double b = 6]) {
  if (profile.graphics == 0) return [];
  return [BoxShadow(color: c, blurRadius: b, offset: const Offset(0, 3))];
}

LinearGradient gloss(Color base) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(base, Colors.white, 0.45)!,
      base,
      Color.lerp(base, Colors.black, 0.25)!,
    ],
  );
}

// Code-drawn garden background: sky, hills, lake, deck, leaves.
class GardenBg extends StatelessWidget {
  final Widget child;
  const GardenBg({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8ED0F5),
              Color(0xFFBFE6A8),
              Color(0xFF7FBF5A),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      ),
      // distant hills
      Positioned(
        left: -60,
        right: -60,
        top: 120,
        child: Container(
          height: 180,
          decoration: const BoxDecoration(
            color: Color(0xFF9CCB7E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.elliptical(300, 120),
              topRight: Radius.elliptical(300, 120),
            ),
          ),
        ),
      ),
      // lake band
      Positioned(
        left: 0,
        right: 0,
        top: 300,
        child: Container(
          height: 90,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5FB8E8), Color(0xFF2E8FD0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      // wooden deck at bottom
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          height: 190,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFC08A4E), Color(0xFF8A5A2B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: List.generate(
              4,
              (_) => Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF6E4420), width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      // leaf clusters, top corners
      const Positioned(left: -18, top: -14, child: LeafCluster()),
      const Positioned(right: -18, top: -14, child: LeafCluster()),
      const Positioned(left: -14, bottom: 150, child: LeafCluster(small: true)),
      const Positioned(right: -14, bottom: 150, child: LeafCluster(small: true)),
      child,
    ]);
  }
}

class LeafCluster extends StatelessWidget {
  final bool small;
  const LeafCluster({super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final s = small ? 26.0 : 44.0;
    return SizedBox(
      width: s * 2.2,
      height: s * 1.6,
      child: Stack(children: [
        Positioned(
          left: 0,
          top: s * 0.4,
          child: _leaf(s, const Color(0xFF3E9B4F)),
        ),
        Positioned(
          left: s * 0.7,
          top: 0,
          child: _leaf(s, const Color(0xFF57B25E)),
        ),
        Positioned(
          left: s * 1.3,
          top: s * 0.5,
          child: _leaf(s * 0.85, const Color(0xFF2F7D3B)),
        ),
      ]),
    );
  }

  Widget _leaf(double s, Color c) {
    return Container(
      width: s,
      height: s * 0.7,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(s),
          bottomRight: Radius.circular(s),
        ),
      ),
    );
  }
}

// Wood header band (back arrow + centered title, optional right widget).
class WoodHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? right;
  const WoodHeader({super.key, required this.title, this.onBack, this.right});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB57A3E), Color(0xFF7A4A22)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: sh(),
        border: Border.all(color: const Color(0xFF5E3A18), width: 2),
      ),
      child: Stack(alignment: Alignment.center, children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: RoundBtn(icon: Icons.arrow_back, onTap: onBack!),
            ),
          ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2))],
          ),
        ),
        if (right != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: right!,
            ),
          ),
      ]),
    );
  }
}

class RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final double size;
  const RoundBtn(
      {super.key,
      required this.icon,
      required this.onTap,
      this.bg = const Color(0xFF6B3F1D),
      this.size = 38});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', profile.sound);
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color.lerp(bg, Colors.white, 0.25)!, bg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: sh(),
          border: Border.all(color: const Color(0xFF4A2A12), width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

// Dark coin pill with gold coin + green + button.
class CoinPill extends StatelessWidget {
  final VoidCallback? onPlus;
  const CoinPill({super.key, this.onPlus});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 4, right: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2410),
        borderRadius: BorderRadius.circular(20),
        boxShadow: sh(),
        border: Border.all(color: const Color(0xFF1F1206), width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE27A), Color(0xFFE8A800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFB8860B), width: 1.5),
          ),
          child: const Icon(Icons.star, size: 15, color: Color(0xFF8A5A00)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '${profile.coins}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        GestureDetector(
          onTap: onPlus,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF3FA34D),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

// Glossy big button (green / blue / cream / brown).
class BigBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const BigBtn(
      {super.key,
      required this.label,
      this.icon,
      required this.color,
      this.textColor = Colors.white,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', profile.sound);
        onTap();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: gloss(color),
          borderRadius: BorderRadius.circular(16),
          boxShadow: sh(),
          border: Border.all(
            color: Color.lerp(color, Colors.black, 0.35)!,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              shadows: textColor == Colors.white
                  ? [const Shadow(color: Colors.black38, offset: Offset(0, 1))]
                  : [],
            ),
          ),
        ]),
      ),
    );
  }
}

// Glossy oval booster button with white icon + white label.
class BoosterBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  const BoosterBtn(
      {super.key,
      required this.label,
      required this.icon,
      required this.color,
      this.badge,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', profile.sound);
        onTap();
      },
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: gloss(color),
            borderRadius: BorderRadius.circular(26),
            boxShadow: sh(),
            border: Border.all(
              color: Color.lerp(color, Colors.black, 0.3)!,
              width: 1.5,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ]),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// Single glossy block cell.
class BlockCell extends StatelessWidget {
  final Color color;
  final double size;
  final bool ghost;
  const BlockCell(
      {super.key, required this.color, required this.size, this.ghost = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: ghost ? null : gloss(color),
        color: ghost ? color.withOpacity(0.35) : null,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: ghost
              ? Colors.white
              : Color.lerp(color, Colors.black, 0.3)!,
          width: ghost ? 2 : 1,
        ),
        boxShadow: ghost || profile.graphics == 0
            ? []
            : [const BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: ghost
          ? null
          : Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: EdgeInsets.all(size * 0.12),
                width: size * 0.35,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(size * 0.1),
                ),
              ),
            ),
    );
  }
}

// A piece drawn at a given cell size.
class PieceView extends StatelessWidget {
  final Piece piece;
  final double cell;
  final bool ghost;
  const PieceView(
      {super.key, required this.piece, required this.cell, this.ghost = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: piece.shape.w * cell,
      height: piece.shape.h * cell,
      child: Stack(
        children: piece.shape.cells
            .map((c) => Positioned(
                  left: c[1] * cell,
                  top: c[0] * cell,
                  child: BlockCell(color: piece.color, size: cell, ghost: ghost),
                ))
            .toList(),
      ),
    );
  }
}

// ---------------- App shell ----------------
class BlockPuzzleApp extends StatelessWidget {
  const BlockPuzzleApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
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
    _boot();
  }

  Future<void> _boot() async {
    await profile.load();
    await Sfx.startMusic(profile.music);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF8ED0F5),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF3FA34D)),
      ),
    );
  }
}

void vibrate() {
  if (profile.vibrate) HapticFeedback.lightImpact();
}

Future<void> infoDialog(
    BuildContext context, String title, String body) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFFFFF3D6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w900, color: Color(0xFF5E3A18))),
      content: Text(body, style: const TextStyle(color: Color(0xFF5E3A18))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK',
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: Color(0xFF3FA34D))),
        ),
      ],
    ),
  );
}

// ---------------- Home ----------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GardenBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              const SizedBox(height: 8),
              Row(children: [
                const CoinPill(),
                const Spacer(),
                Stack(clipBehavior: Clip.none, children: [
                  RoundBtn(
                    icon: Icons.card_giftcard,
                    onTap: () => _open(const DailyScreen()),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 10),
                RoundBtn(
                  icon: Icons.settings,
                  onTap: () => _open(const SettingsScreen()),
                ),
              ]),
              const SizedBox(height: 26),
              _logo(),
              const Spacer(),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.75,
                child: BigBtn(
                  label: 'Play',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _open(const GameScreen()),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                    child: _tile(Icons.calendar_month, 'Daily', 'Challenge',
                        () => _open(const DailyScreen()))),
                const SizedBox(width: 8),
                Expanded(
                    child: _tile(Icons.widgets, 'Shop', '',
                        () => _open(const ShopScreen()))),
                const SizedBox(width: 8),
                Expanded(
                    child: _tile(Icons.emoji_events, 'Achievements', '',
                        () => _open(const AchievementsScreen()))),
                const SizedBox(width: 8),
                Expanded(
                    child: _tile(Icons.sports_esports, 'More', 'Games', () {
                  infoDialog(context, 'More Games',
                      'More games are coming soon. Stay tuned!');
                })),
              ]),
              const SizedBox(height: 18),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _open(Widget w) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => w));
    if (mounted) setState(() {});
  }

  Widget _tile(IconData icon, String l1, String l2, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', profile.sound);
        onTap();
      },
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C6B3A), Color(0xFF6B3F1D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: sh(),
          border: Border.all(color: const Color(0xFF4A2A12), width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              l1,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5),
            ),
          ),
          if (l2.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l2,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _logo() {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 26, bottom: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB57A3E), Color(0xFF7A4A22)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: sh(const Color(0x60000000), 10),
          border: Border.all(color: const Color(0xFF5E3A18), width: 2.5),
        ),
        child: Column(children: [
          _text3d('BLOCK', 62, const Color(0xFFFFC93C)),
          _text3d('PUZZLE', 34, Colors.white),
        ]),
      ),
      Positioned(
        top: -22,
        left: 0,
        right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _cube(const Color(0xFF4DA3FF), -0.12),
          _cube(const Color(0xFFFF5DA2), 0.10),
          _cube(const Color(0xFFFFC93C), -0.08),
          _cube(const Color(0xFF3ED598), 0.12),
        ]),
      ),
    ]);
  }

  Widget _cube(Color c, double rot) {
    return Transform.rotate(
      angle: rot,
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: gloss(c),
          borderRadius: BorderRadius.circular(10),
          boxShadow: sh(),
          border: Border.all(
              color: Color.lerp(c, Colors.black, 0.3)!, width: 1.5),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.all(6),
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _text3d(String t, double size, Color color) {
    return Stack(children: [
      Text(
        t,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF4A2A12),
          letterSpacing: 1.5,
        ),
      ),
      Transform.translate(
        offset: const Offset(0, -3),
        child: Text(
          t,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.5,
          ),
        ),
      ),
    ]);
  }
}

// ---------------- Shop ----------------
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int tab = 0; // 0 Blocks, 1 Themes, 2 Coins
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GardenBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              WoodHeader(
                title: 'Shop',
                onBack: () => Navigator.pop(context),
                right: const CoinPill(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _tabBtn(0, Icons.widgets, 'Blocks')),
                const SizedBox(width: 8),
                Expanded(child: _tabBtn(1, Icons.palette, 'Themes')),
                const SizedBox(width: 8),
                Expanded(child: _tabBtn(2, Icons.monetization_on, 'Coins')),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF7A4A22), width: 2),
                    boxShadow: sh(),
                  ),
                  child: tab == 0
                      ? _blocksList()
                      : tab == 1
                          ? _themesList()
                          : _coinsTab(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(int i, IconData icon, String label) {
    final sel = tab == i;
    return GestureDetector(
      onTap: () {
        Sfx.play('click', profile.sound);
        setState(() => tab = i);
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFE9B8) : const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? const Color(0xFF7A4A22) : const Color(0xFFD9C49A),
            width: sel ? 2 : 1.5,
          ),
          boxShadow: sh(),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF6B3F1D), size: 20),
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFF6B3F1D),
                fontWeight: FontWeight.w800,
                fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _card({required Widget preview, required String name, required Widget right}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3D2AC), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 76,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3D6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3D2AC)),
          ),
          child: Center(child: preview),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
                color: Color(0xFF5E3A18),
                fontWeight: FontWeight.w800,
                fontSize: 16),
          ),
        ),
        right,
      ]),
    );
  }

  Widget _priceBtn(int price, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', profile.sound);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: gloss(const Color(0xFF4CAF50)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: sh(),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star, size: 15, color: Color(0xFFFFE27A)),
          const SizedBox(width: 4),
          Text(
            '$price',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ]),
      ),
    );
  }

  Widget _blocksList() {
    const names = ['Default', 'Wooden', 'Neon', 'Galaxy'];
    const prices = [0, 500, 1000, 1500];
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (_, i) {
        final owned = profile.ownedBlocks.contains(i);
        final equipped = profile.blockTheme == i;
        return _card(
          preview: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: blockPalettes[i]
                .take(4)
                .map((c) => BlockCell(color: c, size: 20))
                .toList(),
          ),
          name: names[i],
          right: equipped
              ? Row(mainAxisSize: MainAxisSize.min, children: const [
                  Text('Equipped',
                      style: TextStyle(
                          color: Color(0xFF3FA34D),
                          fontWeight: FontWeight.w800)),
                  SizedBox(width: 6),
                  Icon(Icons.check_circle,
                      color: Color(0xFF3FA34D), size: 22),
                ])
              : owned
                  ? GestureDetector(
                      onTap: () async {
                        profile.blockTheme = i;
                        await profile.save();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE9B8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF7A4A22)),
                        ),
                        child: const Text('Equip',
                            style: TextStyle(
                                color: Color(0xFF6B3F1D),
                                fontWeight: FontWeight.w900)),
                      ),
                    )
                  : _priceBtn(prices[i], () async {
                      if (profile.coins < prices[i]) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Not enough coins yet.')),
                        );
                        return;
                      }
                      profile.coins -= prices[i];
                      profile.ownedBlocks.add(i);
                      profile.blockTheme = i;
                      await profile.save();
                      setState(() {});
                    }),
        );
      },
    );
  }

  Widget _themesList() {
    const names = ['Garden', 'Wood', 'Night'];
    const prices = [0, 300, 500];
    const cellColors = [
      [Color(0xFFD8B58A), Color(0xFFB98D5E)],
      [Color(0xFF8A5A2B), Color(0xFF6B3F1D)],
      [Color(0xFF3A3A5E), Color(0xFF23233A)],
    ];
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (_, i) {
        final owned = profile.ownedBoards.contains(i);
        final equipped = profile.boardTheme == i;
        return _card(
          preview: SizedBox(
            width: 54,
            height: 54,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: List.generate(
                9,
                (j) => Container(
                  decoration: BoxDecoration(
                    color: cellColors[i][j % 2],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          name: names[i],
          right: equipped
              ? Row(mainAxisSize: MainAxisSize.min, children: const [
                  Text('Equipped',
                      style: TextStyle(
                          color: Color(0xFF3FA34D),
                          fontWeight: FontWeight.w800)),
                  SizedBox(width: 6),
                  Icon(Icons.check_circle,
                      color: Color(0xFF3FA34D), size: 22),
                ])
              : owned
                  ? GestureDetector(
                      onTap: () async {
                        profile.boardTheme = i;
                        await profile.save();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE9B8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF7A4A22)),
                        ),
                        child: const Text('Equip',
                            style: TextStyle(
                                color: Color(0xFF6B3F1D),
                                fontWeight: FontWeight.w900)),
                      ),
                    )
                  : _priceBtn(prices[i], () async {
                      if (profile.coins < prices[i]) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Not enough coins yet.')),
                        );
                        return;
                      }
                      profile.coins -= prices[i];
                      profile.ownedBoards.add(i);
                      profile.boardTheme = i;
                      await profile.save();
                      setState(() {});
                    }),
        );
      },
    );
  }

  Widget _coinsTab() {
    return Column(children: [
      const SizedBox(height: 8),
      const Icon(Icons.monetization_on, size: 56, color: Color(0xFFE8A800)),
      const SizedBox(height: 8),
      Text(
        '${profile.coins} coins',
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF5E3A18)),
      ),
      const SizedBox(height: 8),
      const Text(
        'Earn coins by clearing lines in the game!',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF8A6A42), fontSize: 14),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: BigBtn(
          label: 'Daily Bonus +50',
          icon: Icons.card_giftcard,
          color: const Color(0xFF4CAF50),
          onTap: () async {
            if (profile.dailyClaimed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Already claimed today.')),
              );
              return;
            }
            profile.coins += 50;
            profile.dailyClaimed = true;
            await profile.save();
            setState(() {});
          },
        ),
      ),
    ]);
  }
}

// ---------------- Settings ----------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _toggle(String key) async {
    if (key == 'sound') profile.sound = !profile.sound;
    if (key == 'music') {
      profile.music = !profile.music;
      await Sfx.setMusic(profile.music);
    }
    if (key == 'vibrate') profile.vibrate = !profile.vibrate;
    await profile.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GardenBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              WoodHeader(
                title: 'Settings',
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF7A4A22), width: 2),
                    boxShadow: sh(),
                  ),
                  child: ListView(children: [
                    _switchRow(Icons.volume_up, 'Sound', profile.sound,
                        () => _toggle('sound')),
                    _switchRow(Icons.music_note, 'Music', profile.music,
                        () => _toggle('music')),
                    _switchRow(Icons.vibration, 'Vibrate', profile.vibrate,
                        () => _toggle('vibrate')),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFE3D2AC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Graphics Quality',
                            style: TextStyle(
                                color: Color(0xFF5E3A18),
                                fontWeight: FontWeight.w800,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _qBtn(0, 'Low')),
                            const SizedBox(width: 8),
                            Expanded(child: _qBtn(1, 'Medium')),
                            const SizedBox(width: 8),
                            Expanded(child: _qBtn(2, 'High')),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _linkRow(Icons.language, 'Language', 'English', null),
                    _linkRow(Icons.shield_outlined, 'Privacy Policy', '',
                        () {
                      infoDialog(context, 'Privacy Policy',
                          'Block Puzzle stores your progress only on your own device. No account, no data leaves your phone.');
                    }),
                    _linkRow(Icons.description_outlined, 'Terms of Service',
                        '', () {
                      infoDialog(context, 'Terms of Service',
                          'Block Puzzle is an endless puzzle game. Play calmly, enjoy, and beat your own best score.');
                    }),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _switchRow(IconData icon, String label, bool on, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF6B3F1D), size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                color: Color(0xFF5E3A18),
                fontWeight: FontWeight.w800,
                fontSize: 17),
          ),
        ),
        GestureDetector(
          onTap: () {
            Sfx.play('click', profile.sound);
            tap();
          },
          child: Container(
            width: 56,
            height: 30,
            decoration: BoxDecoration(
              color: on ? const Color(0xFF4CAF50) : const Color(0xFFE8D9B8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC9B58A)),
            ),
            child: AnimatedAlign(
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 3)
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _qBtn(int v, String label) {
    final sel = profile.graphics == v;
    return GestureDetector(
      onTap: () async {
        Sfx.play('click', profile.sound);
        profile.graphics = v;
        await profile.save();
        setState(() {});
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF4CAF50) : const Color(0xFFFFE9B8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: sel ? const Color(0xFF2E7D32) : const Color(0xFFD9C49A)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                color: sel ? Colors.white : const Color(0xFF6B3F1D),
                fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _linkRow(IconData icon, String label, String trail, VoidCallback? tap) {
    return GestureDetector(
      onTap: tap == null
          ? null
          : () {
              Sfx.play('click', profile.sound);
              tap();
            },
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3D2AC)),
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF6B3F1D), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: Color(0xFF5E3A18),
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
          Text(
            trail.isEmpty ? '>' : '$trail >',
            style: const TextStyle(
                color: Color(0xFF8A6A42), fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Daily Challenge ----------------
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  static const int goal = 20;
  static const int reward = 100;

  @override
  Widget build(BuildContext context) {
    final done = profile.dailyLines >= goal;
    final progress = (profile.dailyLines / goal).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      body: GardenBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                RoundBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFE3F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF8FC6E8), width: 1.5),
                      boxShadow: sh(),
                    ),
                    child: const Center(
                      child: Text(
                        'Daily Challenge',
                        style: TextStyle(
                            color: Color(0xFF5E3A18),
                            fontWeight: FontWeight.w900,
                            fontSize: 19),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                RoundBtn(
                  icon: Icons.card_giftcard,
                  onTap: () async {
                    if (done && !profile.dailyClaimed) {
                      profile.coins += reward;
                      profile.dailyClaimed = true;
                      await profile.save();
                      setState(() {});
                    }
                  },
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3D2AC)),
                    boxShadow: sh(),
                  ),
                  child: const Icon(Icons.calendar_month,
                      color: Color(0xFFE53935), size: 30),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Complete today's challenge\nand get rewards!",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        shadows: [
                          Shadow(color: Colors.black45, offset: Offset(0, 1))
                        ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              // progress: 5 check nodes + gift
              Row(children: [
                for (int i = 0; i < 5; i++) ...[
                  _node(progress >= (i + 1) / 5),
                  if (i < 4)
                    Expanded(
                      child: Container(
                        height: 6,
                        color: progress >= (i + 1) / 5
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFD9C49A),
                      ),
                    ),
                ],
                const SizedBox(width: 6),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gloss(const Color(0xFF8A5A2B)),
                    border: Border.all(
                        color: const Color(0xFF5E3A18), width: 1.5),
                    boxShadow: sh(),
                  ),
                  child: const Icon(Icons.card_giftcard,
                      color: Colors.white, size: 24),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF7A4A22), width: 2),
                  boxShadow: sh(),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: GridView.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: List.generate(16, (j) {
                        final colors = blockPalettes[profile.blockTheme];
                        final filled = j % 3 != 2;
                        return Container(
                          decoration: BoxDecoration(
                            color: filled
                                ? colors[j % colors.length]
                                : const Color(0xFFD8B58A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today · ${profile.dailyLines}/$goal lines',
                          style: const TextStyle(
                              color: Color(0xFF5E3A18),
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: BigBtn(
                            label: 'Play',
                            color: const Color(0xFF4CAF50),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const GameScreen(daily: true)),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF7A4A22), width: 2),
                  boxShadow: sh(),
                ),
                child: Row(children: [
                  const Expanded(
                    child: Text(
                      "Today's Reward",
                      style: TextStyle(
                          color: Color(0xFF5E3A18),
                          fontWeight: FontWeight.w800,
                          fontSize: 17),
                    ),
                  ),
                  const Icon(Icons.star, color: Color(0xFFE8A800), size: 26),
                  const SizedBox(width: 4),
                  Text(
                    'x$reward',
                    style: const TextStyle(
                        color: Color(0xFF5E3A18),
                        fontWeight: FontWeight.w900,
                        fontSize: 19),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      if (done && !profile.dailyClaimed) {
                        profile.coins += reward;
                        profile.dailyClaimed = true;
                        await profile.save();
                        setState(() {});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: profile.dailyClaimed
                            ? const Color(0xFFE8D9B8)
                            : done
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE8D9B8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile.dailyClaimed
                            ? 'Claimed'
                            : done
                                ? 'Claim'
                                : '${profile.dailyLines}/$goal',
                        style: TextStyle(
                            color: profile.dailyClaimed || !done
                                ? const Color(0xFF8A6A42)
                                : Colors.white,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _node(bool on) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? const Color(0xFF4CAF50) : const Color(0xFFE8D9B8),
        border: Border.all(
            color: on ? const Color(0xFF2E7D32) : const Color(0xFFC9B58A),
            width: 1.5),
        boxShadow: sh(),
      ),
      child: Icon(Icons.check,
          color: on ? Colors.white : const Color(0xFFB8A888), size: 20),
    );
  }
}

// ---------------- Achievements ----------------
class AchDef {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final Color color;
  final int reward;
  final int Function() cur;
  final int goal;
  const AchDef(this.id, this.name, this.desc, this.icon, this.color,
      this.reward, this.cur, this.goal);
}

List<AchDef> achDefs() => [
      AchDef('first_move', 'First Move', 'Complete your first move',
          Icons.star, const Color(0xFFFF5DA2), 50,
          () => profile.moves > 0 ? 1 : 0, 1),
      AchDef('ten_games', '10 Games', 'Complete 10 games', Icons.star,
          const Color(0xFF7C4DFF), 100, () => profile.games, 10),
      AchDef('block_master', 'Block Master', 'Clear 1000 blocks',
          Icons.emoji_events, const Color(0xFFE8A800), 200,
          () => profile.cleared, 1000),
      AchDef('perfect_clear', 'Perfect Clear', 'Clear 3 lines in one move',
          Icons.emoji_events, const Color(0xFFFF6B35), 200,
          () => profile.maxLines >= 3 ? 1 : 0, 1),
      AchDef('daily_player', 'Daily Player', 'Play 7 days in a row',
          Icons.calendar_month, const Color(0xFF4DA3FF), 150,
          () => profile.dailyStreak, 7),
    ];

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  Widget build(BuildContext context) {
    final defs = achDefs();
    return Scaffold(
      body: GardenBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              WoodHeader(
                title: 'Achievements',
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: const Color(0xFF7A4A22), width: 2),
                    boxShadow: sh(),
                  ),
                  child: ListView.builder(
                    itemCount: defs.length,
                    itemBuilder: (_, i) {
                      final d = defs[i];
                      final c = d.cur();
                      final done = c >= d.goal;
                      final claimed = profile.claimedAch.contains(d.id);
                      final p =
                          (c / d.goal).clamp(0.0, 1.0).toDouble();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFE3D2AC)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: gloss(d.color),
                              boxShadow: sh(),
                            ),
                            child: Icon(d.icon,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  style: const TextStyle(
                                      color: Color(0xFF5E3A18),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                                Text(
                                  d.desc,
                                  style: const TextStyle(
                                      color: Color(0xFF8A6A42),
                                      fontSize: 12.5),
                                ),
                                const SizedBox(height: 5),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 8,
                                    backgroundColor:
                                        const Color(0xFFE8D9B8),
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                            Color(0xFF4CAF50)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(children: [
                            Text(
                              '$c/${d.goal}',
                              style: const TextStyle(
                                  color: Color(0xFF8A6A42),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            if (claimed)
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF3FA34D), size: 26)
                            else if (done)
                              GestureDetector(
                                onTap: () async {
                                  profile.coins += d.reward;
                                  profile.claimedAch.add(d.id);
                                  await profile.save();
                                  setState(() {});
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: sh(),
                                  ),
                                  child: const Icon(
                                      Icons.card_giftcard,
                                      color: Colors.white,
                                      size: 18),
                                ),
                              )
                            else
                              const Icon(Icons.lock,
                                  color: Color(0xFFB8A888), size: 22),
                          ]),
                        ]),
                      );
                    },
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- Game ----------------
class _Snap {
  final List<Color?> board;
  final List<Piece?> tray;
  final int score;
  _Snap(this.board, this.tray, this.score);
}

class GameScreen extends StatefulWidget {
  final bool daily;
  const GameScreen({super.key, this.daily = false});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int n = 8;
  final math.Random _r = math.Random();
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  List<Color?> board = List.filled(64, null);
  List<Piece?> tray = [null, null, null];
  int score = 0;
  int streak = 0;
  int linesTotal = 0;
  String gainText = '';
  int gainKey = 0;
  Set<int> clearing = {};
  Set<int> hintCells = {};
  int hintPiece = -1;
  int hintGen = 0;
  int shuffles = 3;
  int hints = 5;
  int undos = 3;
  _Snap? snap;
  bool over = false;

  // drag state
  Piece? dragPiece;
  int dragSlot = -1;
  Offset dragFinger = Offset.zero;
  int hoverR = -1;
  int hoverC = -1;
  double cell = 36;

  int idx(int r, int c) => r * n + c;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  bool _fits(Piece p, int r, int c) {
    if (r < 0 || c < 0 || r + p.shape.h > n || c + p.shape.w > n) return false;
    for (final cl in p.shape.cells) {
      if (board[idx(r + cl[0], c + cl[1])] != null) return false;
    }
    return true;
  }

  bool _canPlaceAnywhere(Piece p) {
    for (int r = 0; r <= n - p.shape.h; r++) {
      for (int c = 0; c <= n - p.shape.w; c++) {
        if (_fits(p, r, c)) return true;
      }
    }
    return false;
  }

  bool _anyMove() {
    for (final p in tray) {
      if (p != null && _canPlaceAnywhere(p)) return true;
    }
    return false;
  }

  void _prefill() {
    board = List.filled(64, null);
    int placed = 0;
    int tries = 0;
    final palettes = blockPalettes[profile.blockTheme];
    while (placed < 20 && tries < 500) {
      tries++;
      final r = _r.nextInt(n);
      final c = _r.nextInt(n);
      if (board[idx(r, c)] != null) continue;
      board[idx(r, c)] = palettes[_r.nextInt(palettes.length)];
      bool full = true;
      for (int cc = 0; cc < n; cc++) {
        if (board[idx(r, cc)] == null) full = false;
      }
      if (full) {
        board[idx(r, c)] = null;
        continue;
      }
      full = true;
      for (int rr = 0; rr < n; rr++) {
        if (board[idx(rr, c)] == null) full = false;
      }
      if (full) {
        board[idx(r, c)] = null;
        continue;
      }
      placed++;
    }
  }

  void _genTray({bool ensureFit = true}) {
    for (int t = 0; t < 50; t++) {
      final next = [
        randomPiece(_r),
        randomPiece(_r),
        randomPiece(_r),
      ];
      if (!ensureFit || next.any((p) => _canPlaceAnywhere(p))) {
        tray = next;
        return;
      }
    }
    tray = [randomPiece(_r), randomPiece(_r), randomPiece(_r)];
  }

  void _newGame() {
    for (int attempt = 0; attempt < 6; attempt++) {
      _prefill();
      _genTray();
      if (_anyMove()) break;
    }
    score = 0;
    streak = 0;
    linesTotal = 0;
    gainText = '';
    clearing = {};
    hintCells = {};
    hintPiece = -1;
    shuffles = 3;
    hints = 5;
    undos = 3;
    snap = null;
    over = false;
    dragPiece = null;
  }

  Future<void> _place(Piece p, int slot, int r, int c) async {
    snap = _Snap(List.of(board), List.of(tray), score);
    for (final cl in p.shape.cells) {
      board[idx(r + cl[0], c + cl[1])] = p.color;
    }
    profile.moves++;
    score += 10 * p.shape.cells.length;
    tray[slot] = null;

    final rows = <int>[];
    final cols = <int>[];
    for (int rr = 0; rr < n; rr++) {
      bool full = true;
      for (int cc = 0; cc < n; cc++) {
        if (board[idx(rr, cc)] == null) full = false;
      }
      if (full) rows.add(rr);
    }
    for (int cc = 0; cc < n; cc++) {
      bool full = true;
      for (int rr = 0; rr < n; rr++) {
        if (board[idx(rr, cc)] == null) full = false;
      }
      if (full) cols.add(cc);
    }
    final lineCount = rows.length + cols.length;
    if (lineCount > 0) {
      streak++;
      final base =
          lineCount == 1 ? 100 : lineCount == 2 ? 300 : 600 + (lineCount - 3) * 300;
      final bonus = streak > 1 ? 50 * (streak - 1) : 0;
      final gained = base + bonus;
      score += gained;
      profile.coins += 10 * lineCount + (streak > 1 ? 20 : 0);
      int cellsCleared = 0;
      final cells = <int>{};
      for (final rr in rows) {
        for (int cc = 0; cc < n; cc++) {
          cells.add(idx(rr, cc));
        }
      }
      for (final cc in cols) {
        for (int rr = 0; rr < n; rr++) {
          cells.add(idx(rr, cc));
        }
      }
      cellsCleared = cells.length;
      profile.cleared += cellsCleared;
      if (lineCount > profile.maxLines) profile.maxLines = lineCount;
      linesTotal += lineCount;
      if (widget.daily) {
        final before = profile.dailyLines;
        profile.dailyLines += lineCount;
        if (before < 20 && profile.dailyLines >= 20) {
          profile.dailyStreak++;
        }
      }
      gainText = streak > 1 ? '+$gained COMBO x$streak' : '+$gained';
      gainKey++;
      setState(() => clearing = cells);
      if (streak > 1) {
        await Sfx.play('combo', profile.sound);
      } else {
        await Sfx.play('clear', profile.sound);
      }
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      for (final i in cells) {
        board[i] = null;
      }
      setState(() => clearing = {});
    } else {
      streak = 0;
      await Sfx.play('place', profile.sound);
    }
    if (tray.every((p) => p == null)) _genTray();
    vibrate();
    if (score > profile.best) profile.best = score;
    await profile.save();
    if (!mounted) return;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => gainText = '');
    });
    if (!_anyMove()) _gameOver();
  }

  void _gameOver() {
    if (over) return;
    over = true;
    profile.games++;
    if (score > profile.best) profile.best = score;
    profile.save();
    Sfx.play('gameover', profile.sound);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        score: score,
        best: profile.best,
        lines: linesTotal,
        onTryAgain: () {
          Navigator.pop(context);
          setState(_newGame);
        },
        onHome: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _onPanStart(Piece p, int slot, DragStartDetails d) {
    setState(() {
      dragPiece = p;
      dragSlot = slot;
      dragFinger = d.globalPosition;
      hoverR = -1;
      hoverC = -1;
    });
    Sfx.play('pickup', profile.sound);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final p = dragPiece;
    if (p == null) return;
    dragFinger = d.globalPosition;
    final box =
        _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = Offset(dragFinger.dx, dragFinger.dy - 90);
    final local = box.globalToLocal(center);
    final pitch = cell + 2; // board cells have 2px gaps
    final r = ((local.dy - 8 - p.shape.h * pitch / 2) / pitch).round();
    final c = ((local.dx - 8 - p.shape.w * pitch / 2) / pitch).round();
    setState(() {
      hoverR = _fits(p, r, c) ? r : -1;
      hoverC = _fits(p, r, c) ? c : -1;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    final p = dragPiece;
    final slot = dragSlot;
    final r = hoverR;
    final c = hoverC;
    setState(() {
      dragPiece = null;
      dragSlot = -1;
      hoverR = -1;
      hoverC = -1;
    });
    if (p != null && r >= 0 && c >= 0) {
      _place(p, slot, r, c);
    } else {
      Sfx.play('invalid', profile.sound);
    }
  }

  void _doHint() {
    if (hints <= 0) return;
    for (int i = 0; i < tray.length; i++) {
      final p = tray[i];
      if (p == null) continue;
      for (int r = 0; r <= n - p.shape.h; r++) {
        for (int c = 0; c <= n - p.shape.w; c++) {
          if (_fits(p, r, c)) {
            final cells = p.shape.cells
                .map((cl) => idx(r + cl[0], c + cl[1]))
                .toSet();
            hints--;
            hintGen++;
            final gen = hintGen;
            setState(() {
              hintCells = cells;
              hintPiece = i;
            });
            Future.delayed(const Duration(milliseconds: 2500), () {
              if (mounted && gen == hintGen) {
                setState(() {
                  hintCells = {};
                  hintPiece = -1;
                });
              }
            });
            return;
          }
        }
      }
    }
  }

  void _doShuffle() {
    if (shuffles <= 0) return;
    shuffles--;
    _genTray();
    Sfx.play('shuffle', profile.sound);
    setState(() {});
    if (!_anyMove()) _gameOver();
  }

  void _doUndo() {
    if (undos <= 0 || snap == null) return;
    undos--;
    board = List.of(snap!.board);
    tray = List.of(snap!.tray);
    score = snap!.score;
    snap = null;
    streak = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final theme = profile.boardTheme;
    final cellColors = theme == 0
        ? [const Color(0xFFD9BC8E), const Color(0xFFCFA878)]
        : theme == 1
            ? [const Color(0xFF8A5A2B), const Color(0xFF74481F)]
            : [const Color(0xFF3A3A5E), const Color(0xFF2C2C46)];
    return Scaffold(
      body: GardenBg(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, bc) {
            final byW = math.min(screenW - 32, 360.0);
            final byH = bc.maxHeight - 350;
            final boardW = math.min(byW, math.max(byH, 220.0));
            cell = (boardW - 16 - 14) / n;
            return Stack(key: _stackKey, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                const SizedBox(height: 8),
                Row(children: [
                  const CoinPill(),
                  const Spacer(),
                  RoundBtn(
                    icon: Icons.music_note,
                    onTap: () async {
                      profile.music = !profile.music;
                      await Sfx.setMusic(profile.music);
                      await profile.save();
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  RoundBtn(
                    icon: profile.sound
                        ? Icons.volume_up
                        : Icons.volume_off,
                    onTap: () async {
                      profile.sound = !profile.sound;
                      await profile.save();
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  RoundBtn(
                    icon: Icons.pause,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _PausedDialog(
                        onResume: () => Navigator.pop(context),
                        onRestart: () {
                          Navigator.pop(context);
                          setState(_newGame);
                        },
                        onHome: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        onSettings: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  height: 26,
                  child: gainText.isEmpty
                      ? (streak > 1
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                'COMBO x$streak',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13),
                              ),
                            )
                          : null)
                      : Container(
                          key: ValueKey(gainKey),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A2410),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            gainText,
                            style: const TextStyle(
                                color: Color(0xFFFFE27A),
                                fontWeight: FontWeight.w900,
                                fontSize: 14),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                // board
                Container(
                  key: _boardKey,
                  width: boardW,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB57A3E), Color(0xFF7A4A22)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: sh(),
                    border: Border.all(
                        color: const Color(0xFF5E3A18), width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int r = 0; r < n; r++) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int c = 0; c < n; c++) ...[
                              _boardCell(r, c, cell, cellColors),
                              if (c < n - 1) const SizedBox(width: 2),
                            ],
                          ],
                        ),
                        if (r < n - 1) const SizedBox(height: 2),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // tray
                Container(
                  width: boardW,
                  height: 108,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB57A3E), Color(0xFF7A4A22)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: sh(),
                    border: Border.all(
                        color: const Color(0xFF5E3A18), width: 2),
                  ),
                  child: Row(children: [
                    for (int i = 0; i < 3; i++)
                      Expanded(child: Center(child: _traySlot(i))),
                  ]),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BoosterBtn(
                      label: 'Shuffle',
                      icon: Icons.refresh,
                      color: const Color(0xFF4CAF50),
                      onTap: _doShuffle,
                    ),
                    const SizedBox(width: 10),
                    BoosterBtn(
                      label: 'Hint',
                      icon: Icons.lightbulb,
                      color: const Color(0xFFFF9800),
                      badge: '$hints',
                      onTap: _doHint,
                    ),
                    const SizedBox(width: 10),
                    BoosterBtn(
                      label: 'Undo',
                      icon: Icons.undo,
                      color: const Color(0xFF7C4DFF),
                      onTap: _doUndo,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  shuffles == 0 && hints == 0 && undos == 0
                      ? ''
                      : 'Shuffle x$shuffles · Undo x$undos',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Colors.black45, offset: Offset(0, 1))
                      ]),
                ),
              ]),
            ),
            if (dragPiece != null) _floatingPiece(),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _boardCell(int r, int c, double cs, List<Color> cellColors) {
    final i = idx(r, c);
    final filled = board[i];
    final isClearing = clearing.contains(i);
    final isGhost = dragPiece != null &&
        hoverR >= 0 &&
        hoverC >= 0 &&
        dragPiece!.shape.cells.any(
            (cl) => cl[0] + hoverR == r && cl[1] + hoverC == c);
    final isHint = hintCells.contains(i);
    if (filled != null) {
      return Container(
        width: cs,
        height: cs,
        decoration: BoxDecoration(
          color: isClearing ? Colors.white : null,
          borderRadius: BorderRadius.circular(cs * 0.22),
        ),
        child: isClearing
            ? null
            : BlockCell(color: filled, size: cs),
      );
    }
    if (isGhost) {
      return BlockCell(color: dragPiece!.color, size: cs, ghost: true);
    }
    if (isHint) {
      final p = tray[hintPiece];
      if (p != null) {
        return BlockCell(color: p.color, size: cs, ghost: true);
      }
    }
    return Container(
      width: cs,
      height: cs,
      decoration: BoxDecoration(
        color: cellColors[(r + c) % 2],
        borderRadius: BorderRadius.circular(cs * 0.22),
      ),
    );
  }

  Widget _traySlot(int i) {
    final p = tray[i];
    if (p == null || (dragSlot == i && dragPiece != null)) {
      return const SizedBox(width: 60, height: 60);
    }
    final highlighted = hintPiece == i;
    return GestureDetector(
      onPanStart: (d) => _onPanStart(p, i, d),
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        decoration: highlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              )
            : null,
        child: PieceView(piece: p, cell: 20),
      ),
    );
  }

  Widget _floatingPiece() {
    final p = dragPiece!;
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return const SizedBox.shrink();
    final local = stackBox.globalToLocal(dragFinger);
    final w = p.shape.w * 20.0;
    final h = p.shape.h * 20.0;
    return Positioned(
      left: local.dx - w / 2,
      top: local.dy - 90 - h / 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.95,
          child: PieceView(piece: p, cell: 20),
        ),
      ),
    );
  }
}

// ---------------- Paused dialog ----------------
class _PausedDialog extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback onSettings;
  const _PausedDialog(
      {required this.onResume,
      required this.onRestart,
      required this.onHome,
      required this.onSettings});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF7A4A22), width: 3),
            boxShadow: sh(const Color(0x80000000), 12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 54,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB57A3E), Color(0xFF7A4A22)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17),
                ),
              ),
              child: const Center(
                child: Text(
                  'Paused',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(0, 2))
                      ]),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3D6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(17),
                  bottomRight: Radius.circular(17),
                ),
              ),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: BigBtn(
                      label: 'Resume',
                      icon: Icons.play_arrow,
                      color: const Color(0xFF4CAF50),
                      onTap: onResume),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: BigBtn(
                      label: 'Restart',
                      icon: Icons.refresh,
                      color: const Color(0xFF2196F3),
                      onTap: onRestart),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: BigBtn(
                      label: 'Home',
                      icon: Icons.home,
                      color: const Color(0xFFFFE9B8),
                      textColor: const Color(0xFF6B3F1D),
                      onTap: onHome),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: BigBtn(
                      label: 'Settings',
                      icon: Icons.settings,
                      color: const Color(0xFF6B3F1D),
                      onTap: onSettings),
                ),
              ]),
            ),
          ]),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: GestureDetector(
            onTap: onResume,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8A5A2B),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        const Positioned(left: -6, top: -8, child: LeafCluster(small: true)),
        const Positioned(right: -6, top: -8, child: LeafCluster(small: true)),
      ]),
    );
  }
}

// ---------------- Game Over dialog ----------------
class _GameOverDialog extends StatelessWidget {
  final int score;
  final int best;
  final int lines;
  final VoidCallback onTryAgain;
  final VoidCallback onHome;
  const _GameOverDialog(
      {required this.score,
      required this.best,
      required this.lines,
      required this.onTryAgain,
      required this.onHome});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF7A4A22), width: 3),
            boxShadow: sh(const Color(0x80000000), 12),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 54,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB57A3E), Color(0xFF7A4A22)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17),
                ),
              ),
              child: const Center(
                child: Text(
                  'Game Over',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(0, 2))
                      ]),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3D6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(17),
                  bottomRight: Radius.circular(17),
                ),
              ),
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3D2AC)),
                  ),
                  child: Column(children: [
                    const Text(
                      'Your score',
                      style: TextStyle(
                          color: Color(0xFF8A6A42),
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    Text(
                      '$score',
                      style: const TextStyle(
                          color: Color(0xFF5E3A18),
                          fontWeight: FontWeight.w900,
                          fontSize: 34),
                    ),
                    Text(
                      '$lines lines · Best $best',
                      style: const TextStyle(
                          color: Color(0xFF8A6A42),
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: BigBtn(
                      label: 'Try Again',
                      icon: Icons.play_arrow,
                      color: const Color(0xFF4CAF50),
                      onTap: onTryAgain),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: BigBtn(
                      label: 'Home',
                      icon: Icons.home,
                      color: const Color(0xFFFFE9B8),
                      textColor: const Color(0xFF6B3F1D),
                      onTap: onHome),
                ),
              ]),
            ),
          ]),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: GestureDetector(
            onTap: onHome,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8A5A2B),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        const Positioned(left: -6, top: -8, child: LeafCluster(small: true)),
        const Positioned(right: -6, top: -8, child: LeafCluster(small: true)),
      ]),
    );
  }
}
