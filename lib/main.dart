import 'dart:async';
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
/// Wooden header strip used by every dialog, like the picture's brown
/// bars: round back button on the left, title centered.
Widget woodHeader(String title, {VoidCallback? onClose}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(gradient: woodGradient()),
    child: Row(
      children: [
        if (onClose != null)
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFBC6C25), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        if (onClose != null) const SizedBox(width: 40),
      ],
    ),
  );
}

/// How to Play dialog, matching the user's sheet: mini board with a
/// purple piece dropping in, the two steps, green "Got it" button.
Future<void> showHowToDialog(BuildContext context) {
  return showSheet(
    context,
    'How to Play',
    Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: woodGradient(),
                borderRadius: BorderRadius.circular(14),
              ),
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
                        width: 13,
                        height: 13,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: v == null ? const Color(0xFFE9CD9F) : Color(v),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            Positioned(
              top: -26,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(gradient: glossGradient(const Color(0xFFAB47BC)), borderRadius: BorderRadius.circular(3)),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(gradient: glossGradient(const Color(0xFFAB47BC)), borderRadius: BorderRadius.circular(3)),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 34,
              child: Icon(Icons.arrow_downward, color: Color(0xFF1E88E5), size: 30),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: Color(0xFF43A047)),
            SizedBox(width: 6),
            Icon(Icons.circle, size: 8, color: Colors.grey),
            SizedBox(width: 6),
            Icon(Icons.circle, size: 8, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 12),
        const Text('1. Drag the block to the board.\n2. Fill all the spaces to clear.', style: TextStyle(fontSize: 15)),
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
                  backgroundColor: selected ? const Color(0xFF43A047) : const Color(0xFFFDEBD0),
                  foregroundColor: selected ? Colors.white : const Color(0xFF6D4C2F),
                ),
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    // Home, rebuilt as constructed widgets from the user's sheet — never a
    // pasted picture. Dense layout like the picture: top coin bar, big
    // BLOCK + PUZZLE plaque with cubes on top, big board, green Play,
    // four bottom tiles on a wood strip. No big empty gaps.
    const cubeColors = [
      Color(0xFFAB47BC),
      Color(0xFFFF9800),
      Color(0xFF66BB6A),
      Color(0xFFEC407A),
      Color(0xFFFFCA28),
    ];
    const preview = [
      'Y.P..TT.',
      'Y.P.GG..',
      '.BB...O.',
      '.B.PP.O.',
      '...P.CC.',
      'RR...C.Y',
      '..B.....',
      '.G..P...',
    ];
    const cellColor = {
      'Y': Color(0xFFFFCA28),
      'P': Color(0xFFAB47BC),
      'T': Color(0xFF26A69A),
      'G': Color(0xFF66BB6A),
      'B': Color(0xFF42A5F5),
      'O': Color(0xFFFF9800),
      'R': Color(0xFFEF5350),
      'C': Color(0xFFEC407A),
    };
    Widget roundBrownButton(IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: () {
          Sfx.play('click');
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: woodGradient(),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );
    }

    Widget bottomTile(IconData icon, Color iconColor, List<String> lines, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: () {
            Sfx.play('click');
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 30),
                const SizedBox(height: 4),
                for (final line in lines)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      line,
                      softWrap: false,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7EC8F7), Color(0xFFD8F3DC), Color(0xFFFFF3D6)],
                stops: [0.0, 0.45, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(top: -30, left: -30, child: Container(width: 110, height: 110, decoration: const BoxDecoration(color: Color(0xFF66BB6A), shape: BoxShape.circle))),
          Positioned(top: -20, left: 30, child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle))),
          Positioned(top: -30, right: -30, child: Container(width: 110, height: 110, decoration: const BoxDecoration(color: Color(0xFF66BB6A), shape: BoxShape.circle))),
          Positioned(top: -20, right: 30, child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4E342E),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 5, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Color(0xFFFFB300), size: 22),
                            const SizedBox(width: 6),
                            Text(
                              '${profile.coins}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            const SizedBox(width: 6),
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
                      const Spacer(),
                      roundBrownButton(Icons.card_giftcard, () => _daily(context)),
                      const SizedBox(width: 10),
                      roundBrownButton(Icons.settings, () => _settings(context)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 26, 12, 12),
                          decoration: BoxDecoration(
                            gradient: woodGradient(),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'BLOCK',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFFD54F),
                                  shadows: [Shadow(color: Colors.black.withOpacity(0.45), offset: const Offset(0, 3), blurRadius: 0)],
                                ),
                              ),
                              Text(
                                'PUZZLE',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: [Shadow(color: Colors.black.withOpacity(0.45), offset: const Offset(0, 2), blurRadius: 0)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: cubeColors.map((c) {
                          return Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              gradient: glossGradient(c),
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final size = constraints.biggest.shortestSide;
                        final cell = size / 8;
                        return Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: size,
                                height: size,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: woodGradient(),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))],
                                ),
                                child: Column(
                                  children: [
                                    for (int r = 0; r < 8; r++)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            for (int c = 0; c < 8; c++)
                                              Expanded(
                                                child: Container(
                                                  margin: const EdgeInsets.all(1.5),
                                                  decoration: BoxDecoration(
                                                    gradient: preview[r][c] == '.'
                                                        ? null
                                                        : glossGradient(cellColor[preview[r][c]]!),
                                                    color: preview[r][c] == '.' ? const Color(0xFFE9CD9F) : null,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -cell * 0.9,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        width: cell * 0.9,
                                        height: cell * 0.9,
                                        decoration: BoxDecoration(gradient: glossGradient(const Color(0xFFAB47BC)), borderRadius: BorderRadius.circular(5)),
                                      ),
                                      Container(
                                        width: cell * 0.9,
                                        height: cell * 0.9,
                                        decoration: BoxDecoration(gradient: glossGradient(const Color(0xFFAB47BC)), borderRadius: BorderRadius.circular(5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -cell * 0.7,
                                right: cell * 0.6,
                                child: Container(
                                  width: cell * 0.9,
                                  height: cell * 0.9,
                                  decoration: BoxDecoration(gradient: glossGradient(const Color(0xFFFFCA28)), borderRadius: BorderRadius.circular(5)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  bigButton('Play', const Color(0xFF43A047), () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen())).then((_) => setState(() {}));
                  }, icon: Icons.play_arrow),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: woodGradient(),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        bottomTile(Icons.calendar_month, Colors.white, ['Daily', 'Challenge'], () => _daily(context)),
                        const SizedBox(width: 8),
                        bottomTile(Icons.store, Colors.white, ['Shop'], () => _shop(context)),
                        const SizedBox(width: 8),
                        bottomTile(Icons.emoji_events, const Color(0xFFFFC107), ['Achievements'], () => _achievements(context)),
                        const SizedBox(width: 8),
                        bottomTile(Icons.apps, const Color(0xFFCE93D8), ['More', 'Games'], () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('More games coming soon!')));
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
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
          Widget tabBtn(int i, String label, IconData icon, Color iconColor) {
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected ? const Color(0xFFFFCC80) : const Color(0xFFFFF8E7),
                    foregroundColor: const Color(0xFF6D4C2F),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: iconColor, size: 18),
                      const SizedBox(width: 4),
                      Flexible(child: Text(label, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Row(children: [coinChip(), const Spacer()]),
              const SizedBox(height: 12),
              Row(children: [tabBtn(0, 'Blocks', Icons.view_in_ar, const Color(0xFFE53935)), tabBtn(1, 'Themes', Icons.palette, const Color(0xFF8D6E63)), tabBtn(2, 'Coins', Icons.monetization_on, const Color(0xFFFFB300))]),
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
                    trailing: equipped
                        ? Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Colors.white, size: 20),
                          )
                        : ElevatedButton(
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
                      style: ElevatedButton.styleFrom(backgroundColor: owned ? const Color(0xFF8D6E63) : const Color(0xFF43A047)),
                      child: owned
                          ? const Text('Equip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on, color: Colors.white, size: 16),
                                Text(' ${t.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
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
          Widget node(bool filled, {bool gift = false}) {
            return Container(
              width: gift ? 36 : 30,
              height: gift ? 36 : 30,
              decoration: BoxDecoration(
                color: gift ? const Color(0xFFFFB300) : (filled ? const Color(0xFF43A047) : Colors.grey.shade300),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: gift
                  ? const Icon(Icons.card_giftcard, color: Colors.white, size: 20)
                  : (filled ? const Icon(Icons.check, color: Colors.white, size: 18) : const SizedBox.shrink()),
            );
          }

          Widget link(bool filled) {
            return Container(width: 10, height: 3, color: filled ? const Color(0xFF43A047) : Colors.grey.shade300);
          }

          final checks = profile.streakDays.clamp(0, 4);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Complete today\'s challenge and get rewards!'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  node(checks > 0),
                  link(checks > 1),
                  node(checks > 1),
                  link(checks > 2),
                  node(checks > 2),
                  link(checks > 3),
                  node(checks > 3),
                  link(false),
                  node(false, gift: true),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${profile.dailyLines} / $goal lines'),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: (profile.dailyLines / goal).clamp(0.0, 1.0),
                            backgroundColor: Colors.brown.shade100,
                            color: const Color(0xFF43A047),
                            minHeight: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  children: [
                    Icon(Icons.monetization_on, color: Color(0xFFFFB300), size: 34),
                    SizedBox(width: 10),
                    Expanded(child: Text("Today's Reward", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    Text('×100', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
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
          const medalIcons = [Icons.star, Icons.star, Icons.workspace_premium, Icons.emoji_events, Icons.calendar_month];
          const medalColors = [Color(0xFFFFB300), Color(0xFF7E57C2), Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFB8C00)];
          return Column(
            children: defs.asMap().entries.map((e) {
              final d = e.value;
              final mi = e.key;
              final cur = d.$3();
              final complete = cur >= d.$4;
              final claimed = profile.claimedAchievements.contains(d.$1);
              return Card(
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: medalColors[mi], shape: BoxShape.circle),
                    child: Icon(medalIcons[mi], color: Colors.white, size: 26),
                  ),
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
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(color: Color(0xFF43A047), shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 20),
                        )
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                                  Text(' +${d.$5}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          : const Icon(Icons.lock, color: Colors.grey)),
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
    // Game Over dialog, constructed from the user's sheet structure: wood
    // border, red "Game Over" ribbon, cream stats card, Play Again + Home.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: woodGradient(),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(18)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))],
                    ),
                    alignment: Alignment.center,
                    child: const Text('Game Over', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_newBest) const Text('NEW BEST!', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFF8F00))),
                        Text('Score    $_score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Best    ${profile.best}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Coins earned    $_runCoins', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  bigButton('Play Again', const Color(0xFF43A047), () {
                    Navigator.of(ctx).pop();
                    setState(_newGame);
                  }, icon: Icons.replay),
                  const SizedBox(height: 12),
                  bigButton('Home', const Color(0xFF6D4C2F), () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  }, icon: Icons.home),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
    // Paused dialog, constructed from the user's sheet: wood border, cream
    // panel, white "Paused" on the wood header, X top-right, four glossy
    // buttons — Resume green, Restart blue, Home cream, Settings brown.
    Widget menuBtn(String label, IconData icon, Color bg, Color fg, VoidCallback onTap) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Sfx.play('click');
              onTap();
            },
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.lerp(bg, Colors.white, 0.25)!, bg, Color.lerp(bg, Colors.black, 0.12)!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: 10),
                  Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: fg)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: woodGradient(),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Container(
              decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(18)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Paused', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: Color(0xFFBC6C25), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: Column(
                      children: [
                        menuBtn('Resume', Icons.play_arrow, const Color(0xFF43A047), Colors.white, () => Navigator.of(ctx).pop()),
                        const SizedBox(height: 12),
                        menuBtn('Restart', Icons.refresh, const Color(0xFF1E88E5), Colors.white, () {
                          Navigator.of(ctx).pop();
                          setState(_newGame);
                        }),
                        const SizedBox(height: 12),
                        menuBtn('Home', Icons.home, const Color(0xFFFDEBD0), const Color(0xFF6D4C2F), () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        }),
                        const SizedBox(height: 12),
                        menuBtn('Settings', Icons.settings, const Color(0xFF6D4C2F), Colors.white, () {
                          showSettingsDialog(context, () => setState(() {}));
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D4C2F), Color(0xFF4E342E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
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
                  // Tray: exactly 3 random blocks, on the picture's cream strip.
                  Container(
                    height: 104,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7CCC8)),
                    ),
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
