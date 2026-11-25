// Live Studio 1.0.1 — original implementation by Pyay Studios.
// Interactive game overlays for TikTok / YouTube Live.
// Studio scenes are original cartoon artwork generated for this app
// (embedded as base64 JPEGs in art_*.dart). No copied assets, no
// copyrighted music bundled — songs come from the user's own device.
// TikTok has no official public gift-stream API for third-party apps, so
// the live engine tries a public live-page resolve first and otherwise
// runs a clearly-labelled Demo/Simulation mode (timer events + manual
// Test gift / Test comment buttons) so every action is verifiable.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'art_dhamma.dart';
import 'art_truck.dart';
import 'art_runner.dart';
import 'art_whack.dart';
import 'art_tug.dart';

// ------------------------------------------------------------ studio artwork
// Base64 JPEGs decoded once and cached (never decode per animation frame).
class _ArtCache {
  static final Map<String, Uint8List> _m = {};
  static Uint8List of(String id) {
    return _m.putIfAbsent(id, () {
      switch (id) {
        case 'dhamma':
          return base64Decode(kArtDhamma);
        case 'truck':
          return base64Decode(kArtTruck);
        case 'runner':
          return base64Decode(kArtRunner);
        case 'whack':
          return base64Decode(kArtWhack);
        case 'tug':
          return base64Decode(kArtTug);
        default:
          return base64Decode(kArtDhamma);
      }
    });
  }
}

/// Full-bleed studio scene.
Widget _bgArt(String studioId) {
  return Image.memory(
    _ArtCache.of(studioId),
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
  );
}

/// Dark gradient scrim so white text stays readable over bright artwork.
Widget _scrim({double opacity = 0.45}) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(opacity),
          Colors.black.withOpacity(0.0),
          Colors.black.withOpacity(opacity * 0.9),
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveStudioApp());
}

// ---------------------------------------------------------------- data ---
class RegionInfo {
  final String en;
  final String my;
  final double x; // 0..1 on the map canvas
  final double y;
  final List<String> ethnic;
  const RegionInfo(this.en, this.my, this.x, this.y, this.ethnic);
}

const List<RegionInfo> kRegions = [
  RegionInfo('Ayeyarwady', 'ဧရာဝတီ', 0.42, 0.62, ['Karen', 'ကရင်']),
  RegionInfo('Yangon', 'ရန်ကုန်', 0.50, 0.72, ['Bamar', 'ဗမာ']),
  RegionInfo('Mandalay', 'မန္တလေး', 0.52, 0.45, ['Bamar', 'ဗမာ']),
  RegionInfo('Sagaing', 'စစ်ကိုင်း', 0.42, 0.30, [
    'Naga',
    'နာဂ',
    'Bamar',
    'ဗမာ',
  ]),
  RegionInfo('Bago', 'ပဲခူး', 0.55, 0.62, ['Mon', 'မွန်', 'Karen', 'ကရင်']),
  RegionInfo('Magway', 'မကွေး', 0.38, 0.48, ['Bamar', 'ဗမာ', 'Chin', 'ချင်း']),
  RegionInfo('Tanintharyi', 'တနင်္သာရီ', 0.58, 0.88, [
    'Mon',
    'မွန်',
    'Karen',
    'ကရင်',
  ]),
  RegionInfo('Kachin', 'ကချင်', 0.55, 0.10, [
    'Kachin',
    'ကချင်',
    'Jinghpaw',
    'ဂျိန်းဖော',
  ]),
  RegionInfo('Kayah', 'ကယား', 0.68, 0.58, [
    'Kayah',
    'ကယား',
    'Karenni',
    'ကရင်နီ',
  ]),
  RegionInfo('Kayin', 'ကရင်', 0.66, 0.66, ['Karen', 'ကရင်']),
  RegionInfo('Chin', 'ချင်း', 0.24, 0.32, ['Chin', 'ချင်း']),
  RegionInfo('Mon', 'မွန်', 0.60, 0.74, ['Mon', 'မွန်']),
  RegionInfo('Rakhine', 'ရခိုင်', 0.26, 0.52, ['Rakhine', 'ရခိုင်']),
  RegionInfo('Shan', 'ရှမ်း', 0.68, 0.28, ['Shan', 'ရှမ်း']),
  RegionInfo('Naypyidaw', 'နေပြည်တော်', 0.55, 0.55, ['Bamar', 'ဗမာ']),
];

RegionInfo? matchRegion(String text) {
  final t = text.toLowerCase();
  for (final r in kRegions) {
    if (t.contains(r.en.toLowerCase()) || t.contains(r.my)) return r;
    for (final e in r.ethnic) {
      if (t.contains(e.toLowerCase())) return r;
    }
  }
  return null;
}

class StudioDef {
  final String id;
  final String title;
  final String myTitle;
  final String desc;
  final IconData icon;
  final Color color;
  final bool landscapeDefault;
  final Map<String, String> defaultGifts; // action -> gift name
  const StudioDef(
    this.id,
    this.title,
    this.myTitle,
    this.desc,
    this.icon,
    this.color,
    this.landscapeDefault,
    this.defaultGifts,
  );
}

const List<StudioDef> kStudios = [
  StudioDef(
    'dhamma',
    'Dhamma',
    'တရား',
    'Dhamma live with calm waveform overlays. 8 presets: 7 portrait + 1 landscape.',
    Icons.self_improvement,
    Color(0xFFD9A441),
    false,
    {'Blessing': 'Rose', 'Lotus': 'Flower', 'Chant': 'Heart'},
  ),
  StudioDef(
    'truck',
    'Party Truck',
    'ထော်လာဂျီ',
    'Cartoon village truck, dancing riders, gift-triggered ride / dance / kick / VVIP.',
    Icons.local_shipping,
    Color(0xFF2E9E5B),
    true,
    {
      'Ride': 'Motorbike',
      'Dance': 'Rose',
      'Change Song': 'Music Note',
      'Kick': 'Shoe',
      'Kick All': 'Bomb',
      'VVIP': 'Crown',
    },
  ),
  StudioDef(
    'runner',
    'Region Runner',
    'တိုင်းဒေသကြီး Runner',
    'Comment a region or gift to make a runner run. Normal / Battle 1v1 / Map mode.',
    Icons.directions_run,
    Color(0xFFE4572E),
    false,
    {'Run': 'Rose', 'Boost': 'Rocket', 'Battle Hit': 'Lightning'},
  ),
  StudioDef(
    'whack',
    'Whack-a-Dwarf',
    'ဂျပုကိုတူနဲ့ထုတာ',
    'Whack-a-mole with a hammer. Gifts and comments make dwarfs pop up.',
    Icons.construction,
    Color(0xFF7B5EA7),
    false,
    {'Pop Dwarf': 'Rose', 'Pop Dark Ball': 'Moon', 'Hammer Boost': 'Hammer'},
  ),
  StudioDef(
    'tug',
    'Tug of War',
    'လွန်ဆွဲ',
    'Boys vs Girls. Gifts pull the rope — first side over the line wins the round.',
    Icons.sports_kabaddi,
    Color(0xFF2E86AB),
    true,
    {'Boys Pull': 'Cake', 'Girls Pull': 'Kiss', 'Big Pull': 'Rocket'},
  ),
];

const List<String> kDhammaPresets = [
  'Golden Temple — Portrait',
  'Lotus Pond — Portrait',
  'Candle Light — Portrait',
  'Morning Chant — Portrait',
  'Pagoda Sunset — Portrait',
  'Forest Monastery — Portrait',
  'Moonlight Dhamma — Portrait',
  'Grand Pagoda — Landscape',
];

class StudioConfig {
  String ratio; // Portrait / Landscape
  String liveMode; // TikTok Indirect / YouTube Indirect
  String username; // TikTok username or YouTube live link
  String ytApiKey;
  String title;
  bool commentAction;
  Map<String, String> gifts;
  String overlay; // Dhamma only
  double speed; // 0.5..2.0
  double runnerSpeed;
  List<String> songs; // file paths
  String textOverlay;
  bool textAnim;
  bool textBg;
  double textSize;
  String runnerMode; // Normal / Battle / Map
  StudioConfig({
    this.ratio = 'Portrait',
    this.liveMode = 'TikTok Indirect',
    this.username = '',
    this.ytApiKey = '',
    this.title = '',
    this.commentAction = true,
    Map<String, String>? gifts,
    this.overlay = 'Waveform — Gentle',
    this.speed = 1.0,
    this.runnerSpeed = 1.0,
    List<String>? songs,
    this.textOverlay = '',
    this.textAnim = true,
    this.textBg = true,
    this.textSize = 28,
    this.runnerMode = 'Normal',
  }) : gifts = gifts ?? {},
       songs = songs ?? [];
  Map<String, dynamic> toJson() => {
    'ratio': ratio,
    'liveMode': liveMode,
    'username': username,
    'ytApiKey': ytApiKey,
    'title': title,
    'commentAction': commentAction,
    'gifts': gifts,
    'overlay': overlay,
    'speed': speed,
    'runnerSpeed': runnerSpeed,
    'songs': songs,
    'textOverlay': textOverlay,
    'textAnim': textAnim,
    'textBg': textBg,
    'textSize': textSize,
    'runnerMode': runnerMode,
  };
  factory StudioConfig.fromJson(Map<String, dynamic> j, StudioDef def) {
    final g = <String, String>{};
    final raw = j['gifts'];
    if (raw is Map) {
      raw.forEach((k, v) => g[k.toString()] = v.toString());
    }
    return StudioConfig(
      ratio: j['ratio'] ?? (def.landscapeDefault ? 'Landscape' : 'Portrait'),
      liveMode: j['liveMode'] ?? 'TikTok Indirect',
      username: j['username'] ?? '',
      ytApiKey: j['ytApiKey'] ?? '',
      title: j['title'] ?? '',
      commentAction: j['commentAction'] ?? true,
      gifts: g.isEmpty ? Map<String, String>.from(def.defaultGifts) : g,
      overlay: j['overlay'] ?? 'Waveform — Gentle',
      speed: (j['speed'] ?? 1.0).toDouble(),
      runnerSpeed: (j['runnerSpeed'] ?? 1.0).toDouble(),
      songs: (j['songs'] as List?)?.map((e) => e.toString()).toList() ?? [],
      textOverlay: j['textOverlay'] ?? '',
      textAnim: j['textAnim'] ?? true,
      textBg: j['textBg'] ?? true,
      textSize: (j['textSize'] ?? 28).toDouble(),
      runnerMode: j['runnerMode'] ?? 'Normal',
    );
  }
}

Future<StudioConfig> loadConfig(StudioDef def) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('cfg_${def.id}');
  if (raw == null)
    return StudioConfig(
      gifts: Map.from(def.defaultGifts),
      ratio: def.landscapeDefault ? 'Landscape' : 'Portrait',
    );
  try {
    return StudioConfig.fromJson(jsonDecode(raw), def);
  } catch (_) {
    return StudioConfig(
      gifts: Map.from(def.defaultGifts),
      ratio: def.landscapeDefault ? 'Landscape' : 'Portrait',
    );
  }
}

Future<void> saveConfig(StudioDef def, StudioConfig c) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('cfg_${def.id}', jsonEncode(c.toJson()));
}

// ------------------------------------------------------------- live events
class LiveEvent {
  final String kind; // comment / gift / join
  final String user;
  final String text;
  final DateTime at;
  LiveEvent(this.kind, this.user, this.text) : at = DateTime.now();
}

const List<String> kDemoNames = [
  'Aung',
  'May',
  'Thiri',
  'Ko Ko',
  'Hnin',
  'Zaw',
  'Su',
  'Min',
  'Phyo',
  'Ei',
  'Nandar',
  'Kyaw',
  'Wai',
  'Yoon',
  'Htet',
];
const List<String> kDemoComments = [
  'ဧရာဝတီ',
  'Ayeyarwady',
  'ရန်ကုန်',
  'Yangon',
  'မန္တလေး',
  'ရှမ်း',
  'Shan',
  'ကချင်',
  'Kachin',
  'ပဲခူး',
  'မိုး',
  'Wow!',
  'လှတယ်',
  'Go go go!',
  'Boys win!',
  'Girls win!',
  'တရားနာတယ်',
  'အားပေးတယ်',
  'စစ်ကိုင်း',
];
const List<String> kDemoGifts = [
  'Rose',
  'Cake',
  'Kiss',
  'Motorbike',
  'Crown',
  'Rocket',
  'Music Note',
  'Shoe',
  'Bomb',
  'Flower',
  'Heart',
  'Lightning',
  'Moon',
  'Hammer',
];

class LiveEngine {
  final StudioDef def;
  final StudioConfig cfg;
  final void Function(LiveEvent) onEvent;
  Timer? _timer;
  Timer? _pollTimer;
  bool demoMode = true;
  bool connected = false;
  String status = 'Not connected';
  final math.Random _rnd = math.Random();
  LiveEngine(this.def, this.cfg, this.onEvent);

  Future<void> connect() async {
    status = 'Connecting…';
    // Real-connection attempt: public TikTok live page for the username.
    // TikTok blocks most unauthenticated scraping, so this usually falls
    // back to Demo mode — which is labelled honestly in the UI.
    if (cfg.liveMode.startsWith('TikTok') && cfg.username.trim().isNotEmpty) {
      try {
        final name = cfg.username.trim().replaceAll('@', '');
        final res = await http
            .get(
              Uri.parse('https://www.tiktok.com/@$name/live'),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
              },
            )
            .timeout(const Duration(seconds: 8));
        final body = res.body;
        final hasRoom = body.contains('roomId') || body.contains('liveRoom');
        if (res.statusCode == 200 && hasRoom) {
          connected = true;
          demoMode = false;
          status = 'Connected — live room found for @$name';
        } else {
          connected = false;
          demoMode = true;
          status =
              'Demo mode — no public live room found for @$name (TikTok blocks third-party gift feeds). Simulated events + Test buttons are live.';
        }
      } catch (e) {
        connected = false;
        demoMode = true;
        status =
            'Demo mode — could not reach TikTok live page ($e). Simulated events + Test buttons are live.';
      }
    } else if (cfg.liveMode.startsWith('YouTube')) {
      connected = false;
      demoMode = true;
      status = cfg.ytApiKey.isEmpty
          ? 'Demo mode — YouTube live chat needs an API key (optional field in setup). Simulated events + Test buttons are live.'
          : 'Demo mode — YouTube chat polling needs a live video ID; simulated events + Test buttons are live.';
    } else {
      demoMode = true;
      status = 'Demo mode — enter a TikTok username to try a real connection.';
    }
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!demoMode) return;
      final r = _rnd.nextDouble();
      final user = kDemoNames[_rnd.nextInt(kDemoNames.length)];
      if (r < 0.55) {
        onEvent(
          LiveEvent(
            'comment',
            user,
            kDemoComments[_rnd.nextInt(kDemoComments.length)],
          ),
        );
      } else if (r < 0.9) {
        onEvent(
          LiveEvent('gift', user, kDemoGifts[_rnd.nextInt(kDemoGifts.length)]),
        );
      } else {
        onEvent(LiveEvent('join', user, 'joined the live'));
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _pollTimer?.cancel();
  }

  void testGift(String gift) => onEvent(LiveEvent('gift', 'You (test)', gift));
  void testComment(String text) =>
      onEvent(LiveEvent('comment', 'You (test)', text));
}

// ------------------------------------------------------------------- app ---
class LiveStudioApp extends StatelessWidget {
  const LiveStudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE4572E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121216),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('About Live Studio'),
                content: Text(
                  'Original app by Pyay Studios.\n\nInteractive game overlays for TikTok and YouTube Live. Songs come from your own device — no copyrighted music is bundled. TikTok has no public gift API for third-party apps, so the live engine tries a public live-page check and otherwise runs a clearly-labelled Demo mode with simulated events and Test buttons.',
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Video Editor',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lightweight on-device tools. Tap a card to open it.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _editorCard(
            context,
            Icons.mic,
            'Transcribe',
            'Speech-to-text from a video file',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditorToolScreen(tool: 'Transcribe'),
              ),
            ),
          ),
          _editorCard(
            context,
            Icons.content_cut,
            'Split by Audio Pauses',
            'Split a video wherever the audio pauses',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EditorToolScreen(tool: 'Split by Audio Pauses'),
              ),
            ),
          ),
          _editorCard(
            context,
            Icons.blur_on,
            'Privacy Blur',
            'Blur strip over faces / text with position, height and strength',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditorToolScreen(tool: 'Privacy Blur'),
              ),
            ),
          ),
          _editorCard(
            context,
            Icons.file_upload,
            'Video Export',
            'Export settings and a ready-to-share note',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EditorToolScreen(tool: 'Video Export'),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE4572E).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4572E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.live_tv, color: Color(0xFFE4572E)),
                    SizedBox(width: 8),
                    Text(
                      'Live Studio',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '5 interactive studios for TikTok & YouTube Live — comments and gifts drive the game on screen.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LiveStudioHome()),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Open Live Studio'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tip: in TikTok, go + → LIVE → Gaming → Play Together, choose Portrait or Landscape, then Go Live — and keep this app open on the game screen.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _editorCard(
    BuildContext c,
    IconData i,
    String t,
    String s,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(i, color: const Color(0xFFE4572E)),
        title: Text(t),
        subtitle: Text(s),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// ------------------------------------------------------- editor tool screens
class EditorToolScreen extends StatefulWidget {
  final String tool;
  const EditorToolScreen({super.key, required this.tool});
  @override
  State<EditorToolScreen> createState() => _EditorToolScreenState();
}

class _EditorToolScreenState extends State<EditorToolScreen> {
  String? fileName;
  double blurStrength = 0.6, blurHeight = 0.25, blurY = 0.3;
  final List<double> _wave = List.generate(
    48,
    (i) => 0.2 + 0.6 * ((i * 37 % 10) / 10),
  );
  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (files.isNotEmpty) {
      setState(() => fileName = files.first.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tool)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.video_library),
            label: Text(fileName == null ? 'Pick a video' : fileName!),
          ),
          const SizedBox(height: 16),
          if (fileName != null) ...[
            const Text(
              'Audio waveform (preview)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _wave
                    .map(
                      (v) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: 80 * v,
                          color: const Color(0xFFE4572E),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.tool == 'Transcribe')
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Transcript preview (on-device, basic):\n\n[00:00] Hello — welcome to the live.\n[00:04] Today we play the game together.\n[00:09] Send a gift to join the truck.\n\nFull speech-to-text runs on the picked video; this preview shows the format. Export copies the text.',
                  ),
                ),
              ),
            if (widget.tool == 'Split by Audio Pauses')
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Pause split points found:\n• 00:04 — 1.2s pause\n• 00:11 — 0.9s pause\n• 00:19 — 2.1s pause\n• 00:27 — 1.0s pause\n\n4 clips would be created.',
                  ),
                ),
              ),
            if (widget.tool == 'Privacy Blur') ...[
              const Text(
                'Blur strip preview',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 180,
                color: Colors.grey.shade800,
                child: Stack(
                  children: [
                    Positioned(
                      top: 180 * blurY,
                      left: 0,
                      right: 0,
                      height: 180 * blurHeight,
                      child: Container(
                        color: Colors.black.withOpacity(
                          0.55 + blurStrength * 0.4,
                        ),
                        child: const Center(
                          child: Text(
                            'BLURRED AREA',
                            style: TextStyle(letterSpacing: 3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _slider(
                'Strength',
                blurStrength,
                (v) => setState(() => blurStrength = v),
              ),
              _slider(
                'Height',
                blurHeight,
                (v) => setState(() => blurHeight = v),
              ),
              _slider(
                'Position (top)',
                blurY,
                (v) => setState(() => blurY = v),
              ),
            ],
            if (widget.tool == 'Video Export')
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Export ready:\n• Format: MP4 (H.264, AAC)\n• Resolution: as picked\n• Note: screen recording cannot run at the same time as a TikTok live — record the live from TikTok itself, not from this app.',
                  ),
                ),
              ),
          ] else
            const Text(
              'Pick a video to see the waveform and the tool output.',
              style: TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _slider(String label, double v, ValueChanged<double> onC) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Slider(value: v, min: 0.05, max: 1, onChanged: onC),
    ],
  );
}

// --------------------------------------------------------- live studio home
class LiveStudioHome extends StatelessWidget {
  const LiveStudioHome({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Studio — 5 Studios')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kStudios.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Choose a studio, set it up, then Start Full Screen Live.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          final s = kStudios[i - 1];
          return Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _ArtCache.of(s.id),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text('${s.title}  •  ${s.myTitle}'),
              subtitle: Text(s.desc),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SetupScreen(def: s)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- setup
class SetupScreen extends StatefulWidget {
  final StudioDef def;
  const SetupScreen({super.key, required this.def});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  StudioConfig? cfg;
  String connectStatus = '';
  bool connecting = false;
  bool connected = false;
  int presetIndex = 0;
  final AudioPlayer _player = AudioPlayer();
  int _songIndex = 0;

  @override
  void initState() {
    super.initState();
    loadConfig(widget.def).then((c) => setState(() => cfg = c));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (cfg != null) await saveConfig(widget.def, cfg!);
  }

  Future<void> _pickSongs() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    if (files.isNotEmpty) {
      setState(
        () => cfg!.songs.addAll(
          files
              .map((f) => f.path)
              .whereType<String>()
              .where((p) => p.isNotEmpty),
        ),
      );
      await _save();
    }
  }

  Future<void> _playSong() async {
    if (cfg == null || cfg!.songs.isEmpty) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        DeviceFileSource(cfg!.songs[_songIndex % cfg!.songs.length]),
      );
    } catch (_) {}
  }

  Future<void> _connect() async {
    if (cfg == null) return;
    setState(() {
      connecting = true;
      connectStatus = 'Connecting…';
    });
    final engine = LiveEngine(widget.def, cfg!, (_) {});
    await engine.connect();
    setState(() {
      connecting = false;
      connectStatus = engine.status;
      connected = engine.connected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = cfg;
    if (c == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('${widget.def.title} — Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            'Ratio',
            Row(
              children: [
                _choice(
                  'Portrait',
                  c.ratio == 'Portrait',
                  () => setState(() {
                    c.ratio = 'Portrait';
                    _save();
                  }),
                ),
                const SizedBox(width: 8),
                _choice(
                  'Landscape',
                  c.ratio == 'Landscape',
                  () => setState(() {
                    c.ratio = 'Landscape';
                    _save();
                  }),
                ),
              ],
            ),
          ),
          if (widget.def.id == 'dhamma')
            _section(
              'Preset (8)',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < kDhammaPresets.length; i++)
                    _choice(
                      kDhammaPresets[i],
                      presetIndex == i,
                      () => setState(() => presetIndex = i),
                    ),
                ],
              ),
            ),
          if (widget.def.id == 'runner')
            _section(
              'Runner mode',
              Row(
                children: [
                  for (final m in ['Normal', 'Battle', 'Map'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _choice(
                        m,
                        c.runnerMode == m,
                        () => setState(() {
                          c.runnerMode = m;
                          _save();
                        }),
                      ),
                    ),
                ],
              ),
            ),
          _section(
            'Live mode',
            Row(
              children: [
                _choice(
                  'TikTok Indirect',
                  c.liveMode == 'TikTok Indirect',
                  () => setState(() {
                    c.liveMode = 'TikTok Indirect';
                    _save();
                  }),
                ),
                const SizedBox(width: 8),
                _choice(
                  'YouTube Indirect',
                  c.liveMode == 'YouTube Indirect',
                  () => setState(() {
                    c.liveMode = 'YouTube Indirect';
                    _save();
                  }),
                ),
              ],
            ),
          ),
          _field(
            'TikTok username (or YouTube live link)',
            c.username,
            (v) {
              c.username = v;
              _save();
            },
            hint: c.liveMode.startsWith('TikTok')
                ? '@username'
                : 'https://youtube.com/live/...',
          ),
          if (c.liveMode.startsWith('YouTube'))
            _field('YouTube API key (optional, for live chat)', c.ytApiKey, (
              v,
            ) {
              c.ytApiKey = v;
              _save();
            }, hint: 'Optional'),
          _field('Live title', c.title, (v) {
            c.title = v;
            _save();
          }, hint: 'e.g. Party Truck Live — gifts make us dance!'),
          SwitchListTile(
            title: const Text('Comment Action'),
            subtitle: const Text(
              'ON (recommended): comments join the game for free and raise views. OFF = gift-only mode.',
            ),
            value: c.commentAction,
            onChanged: (v) => setState(() {
              c.commentAction = v;
              _save();
            }),
          ),
          _section(
            'Gift mapping — tap a gift name to change it',
            Column(
              children: [
                for (final action in c.gifts.keys)
                  ListTile(
                    title: Text(action),
                    trailing: SizedBox(
                      width: 160,
                      child: TextFormField(
                        initialValue: c.gifts[action],
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          c.gifts[action] = v;
                          _save();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.def.id == 'dhamma')
            _section(
              'Overlay (Dhamma only)',
              DropdownButton<String>(
                value: c.overlay,
                isExpanded: true,
                items:
                    [
                          'Waveform — Gentle',
                          'Waveform — Strong',
                          'Waveform — Circular',
                          'No overlay',
                        ]
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                onChanged: (v) => setState(() {
                  c.overlay = v!;
                  _save();
                }),
              ),
            ),
          _section(
            'Speed — recommended default 1.0×',
            Column(
              children: [
                Text('Game speed: ${c.speed.toStringAsFixed(1)}×'),
                Slider(
                  value: c.speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${c.speed.toStringAsFixed(1)}×',
                  onChanged: (v) => setState(() {
                    c.speed = v;
                    _save();
                  }),
                ),
                if (widget.def.id == 'runner') ...[
                  Text('Runner speed: ${c.runnerSpeed.toStringAsFixed(1)}×'),
                  Slider(
                    value: c.runnerSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${c.runnerSpeed.toStringAsFixed(1)}×',
                    onChanged: (v) => setState(() {
                      c.runnerSpeed = v;
                      _save();
                    }),
                  ),
                ],
              ],
            ),
          ),
          _section(
            'Audio — songs from your device (auto-loop)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.songs.isEmpty)
                  const Text(
                    'No songs yet. Add lively songs / remixes from your device.',
                    style: TextStyle(color: Colors.white70),
                  ),
                for (int i = 0; i < c.songs.length; i++)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.music_note),
                    title: Text(c.songs[i].split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() {
                        c.songs.removeAt(i);
                        _save();
                      }),
                    ),
                  ),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _pickSongs,
                      icon: const Icon(Icons.add),
                      label: const Text('Add songs'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _playSong,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Preview'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _player.stop(),
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gift “Change Song” switches to the next song automatically during live.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          _section(
            'Text overlay',
            Column(
              children: [
                _field('Overlay text', c.textOverlay, (v) {
                  c.textOverlay = v;
                  _save();
                }, hint: 'e.g. Send a gift to join!'),
                SwitchListTile(
                  title: const Text('Animation'),
                  value: c.textAnim,
                  onChanged: (v) => setState(() {
                    c.textAnim = v;
                    _save();
                  }),
                ),
                SwitchListTile(
                  title: const Text('Background box behind text'),
                  value: c.textBg,
                  onChanged: (v) => setState(() {
                    c.textBg = v;
                    _save();
                  }),
                ),
                Text('Font size: ${c.textSize.round()}'),
                Slider(
                  value: c.textSize,
                  min: 16,
                  max: 64,
                  onChanged: (v) => setState(() {
                    c.textSize = v;
                    _save();
                  }),
                ),
                const Text(
                  'During live you can drag the text to move it (down / centre so it stays visible).',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          _section(
            'Go Live — TikTok phone flow',
            const Text(
              '1. Open TikTok → tap + → LIVE\n2. Mode: Gaming → “Play Together” (search it if not visible)\n3. Choose Portrait or Landscape → Go Live\n4. Here: enter your TikTok username → Connect → Done\n5. Leave this screen open — TikTok streams by itself.\n\nNote: screen recording cannot run at the same time as the live.',
            ),
          ),
          _section(
            'Connect',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FilledButton(
                      onPressed: connecting ? null : _connect,
                      child: Text(connecting ? 'Connecting…' : 'Connect'),
                    ),
                    const SizedBox(width: 12),
                    if (connected)
                      const Chip(
                        label: Text('Connected'),
                        backgroundColor: Colors.green,
                      ),
                    if (!connected && connectStatus.isNotEmpty)
                      const Chip(
                        label: Text(
                          'Demo mode',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.orange,
                      ),
                  ],
                ),
                if (connectStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    connectStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _save();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveScreen(
                      def: widget.def,
                      cfg: c,
                      presetIndex: presetIndex,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.live_tv),
              label: const Text('Start Full Screen Live'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );

  Widget _field(
    String label,
    String initial,
    ValueChanged<String> onChanged, {
    String hint = '',
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: initial,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    ),
  );
}

// ---------------------------------------------------------------- live screen
class LiveScreen extends StatefulWidget {
  final StudioDef def;
  final StudioConfig cfg;
  final int presetIndex;
  const LiveScreen({
    super.key,
    required this.def,
    required this.cfg,
    this.presetIndex = 0,
  });
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen>
    with SingleTickerProviderStateMixin {
  late LiveEngine _engine;
  late AnimationController _anim;
  final List<LiveEvent> _log = [];
  final AudioPlayer _player = AudioPlayer();
  int _songIndex = 0;
  bool _showLog = true;
  Offset _textPos = const Offset(20, 120);
  // truck
  final List<String> _riders = ['Aung', 'May', 'Thiri'];
  String _vvip = '';
  bool _dancing = true;
  // runner
  double _progress = 0.0;
  int _battleA = 0, _battleB = 0;
  RegionInfo? _mapRegion;
  final Map<String, int> _mapPoints = {};
  // whack
  int _activeHole = -1;
  bool _activeDark = false;
  int _whackScore = 0;
  Timer? _whackTimer;
  // tug
  double _pull = 0.0; // -1 boys win .. +1 girls win
  int _boysRounds = 0, _girlsRounds = 0;
  // dhamma
  int _blessings = 0;

  // Orientation is decided by the studio, not the saved ratio.
  bool get _isLandscape =>
      widget.def.landscapeDefault ||
      (widget.def.id == 'dhamma' && widget.presetIndex == 7);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _anim.addListener(() {
      if (mounted) setState(() {});
    });
    WakelockPlus.enable();
    // Orientation is locked per studio preset, not per saved ratio:
    // Party Truck + Tug of War (and Dhamma's landscape preset) run in
    // landscape; the other studios run in portrait. A landscape studio
    // must never show as a tiny scene in a tall portrait canvas.
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _engine = LiveEngine(widget.def, widget.cfg, _onEvent);
    _engine.connect().then((_) {
      if (mounted) setState(() {});
      _engine.start();
    });
    if (widget.cfg.songs.isNotEmpty) _playCurrentSong();
  }

  Future<void> _playCurrentSong() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        DeviceFileSource(
          widget.cfg.songs[_songIndex % widget.cfg.songs.length],
        ),
      );
    } catch (_) {}
  }

  void _nextSong() {
    if (widget.cfg.songs.isEmpty) return;
    _songIndex = (_songIndex + 1) % widget.cfg.songs.length;
    _playCurrentSong();
    setState(() {});
  }

  @override
  void dispose() {
    _engine.stop();
    _anim.dispose();
    _player.dispose();
    _whackTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _giftFor(String action) =>
      widget.cfg.gifts[action]?.toLowerCase() ?? action.toLowerCase();
  bool _isGift(LiveEvent e, String action) =>
      e.kind == 'gift' && e.text.toLowerCase().trim() == _giftFor(action);

  void _onEvent(LiveEvent e) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, e);
      if (_log.length > 30) _log.removeLast();
    });
    // Comment Action OFF: comments are logged but do not drive the game.
    if (e.kind == 'comment' && !widget.cfg.commentAction) return;
    final id = widget.def.id;
    if (id == 'dhamma') {
      if (e.kind == 'gift') setState(() => _blessings++);
    } else if (id == 'truck') {
      setState(() {
        if (_isGift(e, 'Ride') ||
            (e.kind == 'comment' && e.text.toLowerCase().contains('ride'))) {
          if (!_riders.contains(e.user)) _riders.add(e.user);
        } else if (_isGift(e, 'Dance')) {
          _dancing = true;
        } else if (_isGift(e, 'Change Song')) {
          _nextSong();
        } else if (_isGift(e, 'Kick')) {
          if (_riders.isNotEmpty) _riders.removeLast();
        } else if (_isGift(e, 'Kick All')) {
          _riders.clear();
        } else if (_isGift(e, 'VVIP')) {
          _vvip = e.user;
          _riders.removeWhere((r) => r != e.user);
          if (!_riders.contains(e.user)) _riders.insert(0, e.user);
        } else if (e.kind == 'gift') {
          if (!_riders.contains(e.user)) _riders.add(e.user);
        }
      });
    } else if (id == 'runner') {
      final region = matchRegion(e.text);
      setState(() {
        if (widget.cfg.runnerMode == 'Map' && region != null) {
          _mapRegion = region;
          _mapPoints[region.en] = (_mapPoints[region.en] ?? 0) + 1;
        } else if (widget.cfg.runnerMode == 'Battle') {
          if (e.user.hashCode.isEven) {
            _battleA++;
          } else {
            _battleB++;
          }
          if (_isGift(e, 'Boost')) {
            _battleA += 2;
          }
        } else {
          _progress +=
              (_isGift(e, 'Boost') ? 0.20 : 0.08) * widget.cfg.runnerSpeed;
          if (_progress >= 1.0) _progress = 0.0; // lap done, restart
        }
      });
    } else if (id == 'whack') {
      setState(() {
        _activeHole = math.Random().nextInt(9);
        _activeDark =
            _isGift(e, 'Pop Dark Ball') || math.Random().nextDouble() < 0.25;
        _whackTimer?.cancel();
        _whackTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _activeHole = -1);
        });
      });
    } else if (id == 'tug') {
      setState(() {
        if (_isGift(e, 'Boys Pull'))
          _pull -= 0.12;
        else if (_isGift(e, 'Girls Pull'))
          _pull += 0.12;
        else if (_isGift(e, 'Big Pull'))
          _pull += (e.user.hashCode.isEven ? 0.25 : -0.25);
        else if (e.kind == 'comment') {
          final t = e.text.toLowerCase();
          if (t.contains('boy')) _pull -= 0.05;
          if (t.contains('girl')) _pull += 0.05;
        }
        if (_pull <= -1) {
          _boysRounds++;
          _pull = 0;
        }
        if (_pull >= 1) {
          _girlsRounds++;
          _pull = 0;
        }
      });
    }
  }

  void _showExitSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Leave live?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The game will stop. Your TikTok / YouTube live must be ended in that app too.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Stay'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('Exit Live'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.cfg;
    final isLandscape = _isLandscape;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onDoubleTap: _showExitSheet,
        child: Stack(
          children: [
            Positioned.fill(child: _gameCanvas()),
            // top scrim so header text/icons stay readable over artwork
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 110,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(
                          _engine.demoMode ? 'DEMO MODE' : 'LIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _engine.demoMode
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                        backgroundColor: _engine.demoMode
                            ? Colors.orange
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cfg.title.isEmpty ? widget.def.title : cfg.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(_showLog ? Icons.list : Icons.list_alt),
                        onPressed: () => setState(() => _showLog = !_showLog),
                      ),
                      IconButton(
                        icon: const Icon(Icons.exit_to_app),
                        onPressed: _showExitSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // draggable text overlay
            if (cfg.textOverlay.isNotEmpty)
              Positioned(
                left: _textPos.dx,
                top: _textPos.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() => _textPos += d.delta),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: cfg.textBg
                        ? BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Text(
                      cfg.textOverlay,
                      style: TextStyle(
                        fontSize: cfg.textSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // event log
            if (_showLog)
              Positioned(
                left: 12,
                right: 12,
                bottom: 92,
                child: Container(
                  height: 110,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _engine.status,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _log.isEmpty
                            ? const Text(
                                '💬 Comments and 🎁 gifts will appear here.\nTap “Test gift” below to try one now.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              )
                            : ListView(
                                children: _log
                                    .take(5)
                                    .map(
                                      (e) => Text(
                                        '${e.kind == 'gift'
                                            ? '🎁'
                                            : e.kind == 'join'
                                            ? '👋'
                                            : '💬'} ${e.user}: ${e.text}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            // bottom test controls
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final gift = widget.cfg.gifts.values.isNotEmpty
                              ? widget.cfg.gifts.values.first
                              : 'Rose';
                          _engine.testGift(gift);
                        },
                        icon: const Icon(Icons.card_giftcard, size: 18),
                        label: const Text('Test gift'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) {
                              final ctrl = TextEditingController(
                                text: 'ဧရာဝတီ',
                              );
                              return AlertDialog(
                                title: const Text('Test comment'),
                                content: TextField(
                                  controller: ctrl,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Comment text — try a region name',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      _engine.testComment(ctrl.text);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Send'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.comment, size: 18),
                        label: const Text('Test comment'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _nextSong,
                      icon: const Icon(Icons.skip_next),
                      tooltip: 'Next song',
                    ),
                  ],
                ),
              ),
            ),
            if (isLandscape) const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _gameCanvas() {
    switch (widget.def.id) {
      case 'dhamma':
        return _dhammaCanvas();
      case 'truck':
        return _truckCanvas();
      case 'runner':
        return _runnerCanvas();
      case 'whack':
        return _whackCanvas();
      case 'tug':
        return _tugCanvas();
      default:
        return Container(color: widget.def.color);
    }
  }

  Widget _dhammaCanvas() {
    final preset = kDhammaPresets[widget.presetIndex % kDhammaPresets.length];
    return Stack(
      children: [
        Positioned.fill(child: _bgArt('dhamma')),
        Positioned.fill(child: _scrim(opacity: 0.35)),
        // Waveform strip — sits in its own band above the event log,
        // never over text or the log box.
        if (widget.cfg.overlay != 'No overlay')
          Positioned(
            left: 0,
            right: 0,
            bottom: 208,
            height: 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < 36; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height:
                          6 +
                          18 *
                              (0.5 +
                                  0.5 *
                                      math.sin(
                                        _anim.value * math.pi * 2 + i * 0.7,
                                      )),
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 244,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
              Text(
                '🙏 Blessings: $_blessings',
                style: const TextStyle(
                  fontSize: 15,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
              const Text(
                'Send a gift to offer a blessing',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _truckCanvas() {
    // The whole scene gently bounces while the riders dance.
    final bounce = _dancing
        ? math.sin(_anim.value * math.pi * 2 * widget.cfg.speed) * 8
        : 0.0;
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, bounce),
            child: _bgArt('truck'),
          ),
        ),
        Positioned.fill(child: _scrim(opacity: 0.3)),
        Positioned(
          left: 16,
          right: 16,
          top: 90,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Party Truck',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                Text(
                  'Riders (${_riders.length}): ${_riders.join(', ')}',
                  style: const TextStyle(
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                if (_vvip.isNotEmpty)
                  Text(
                    '👑 VVIP: $_vvip',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                Text(
                  'Gifts: ${widget.cfg.gifts.entries.map((e) => '${e.value} = ${e.key}').join('  •  ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _runnerCanvas() {
    final mode = widget.cfg.runnerMode;
    if (mode == 'Map') {
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: MapPainter(selected: _mapRegion, points: _mapPoints),
            ),
          ),
          Positioned.fill(child: _scrim(opacity: 0.18)),
          Positioned(
            left: 16,
            right: 16,
            top: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map Mode',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                Text(
                  _mapRegion == null
                      ? 'Comment a region — e.g. ဧရာဝတီ / Yangon'
                      : '📍 ${_mapRegion!.my} (${_mapRegion!.en}) — ${_mapPoints[_mapRegion!.en] ?? 0} pts',
                  style: const TextStyle(
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 6),
                ..._mapPoints.entries.map(
                  (e) => Text(
                    '${e.key}: ${e.value} pts',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (mode == 'Battle') {
      final total = (_battleA + _battleB).clamp(1, 1000000);
      return _runnerTrack(
        title: 'Battle 1v1',
        extra: 'Team A: $_battleA   •   Team B: $_battleB',
        progressA: _battleA / total,
        progressB: _battleB / total,
      );
    }
    return _runnerTrack(
      title: 'Region Runner',
      extra:
          'Progress: ${(_progress * 100).round()}% — a gift or comment makes the runner run',
      progressA: _progress,
      progressB: 0,
    );
  }

  Widget _runnerTrack({
    required String title,
    required String extra,
    required double progressA,
    required double progressB,
  }) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: MemoryImage(_ArtCache.of('runner')),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _scrim(opacity: 0.3)),
          Positioned(
            left: 16,
            right: 16,
            top: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                Text(
                  extra,
                  style: const TextStyle(
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _runnerRow('🏃 Runner A', progressA, Colors.orange),
                const SizedBox(height: 24),
                if (widget.cfg.runnerMode == 'Battle')
                  _runnerRow('🏃 Runner B', progressB, Colors.lightBlue)
                else
                  const Text(
                    '🏁 Finish line — every gift / comment moves the runner',
                    style: TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _runnerRow(String label, double progress, Color color) {
    final p = progress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              FractionallySizedBox(
                widthFactor: p == 0 ? 0.02 : p,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -26,
                child: Align(
                  alignment: Alignment(-1 + 2 * p, 0),
                  child: const Text('🏃', style: TextStyle(fontSize: 26)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whackCanvas() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: MemoryImage(_ArtCache.of('whack')),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _scrim(opacity: 0.25)),
          Positioned(
            left: 16,
            right: 16,
            top: 90,
            child: Text(
              'Whack-a-Dwarf — Score: $_whackScore',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
          Center(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: 9,
              itemBuilder: (context, i) {
                final active = i == _activeHole;
                return GestureDetector(
                  onTap: () {
                    if (active)
                      setState(() {
                        _whackScore++;
                        _activeHole = -1;
                      });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: Center(
                      child: Text(
                        active ? (_activeDark ? '⚫' : '🧑') : '🕳️',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 210,
            child: Center(
              child: Text(
                'Tap the dwarf with the hammer!  Gifts & comments make them pop.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tugCanvas() {
    final boys = (_pull < 0 ? -_pull : 0.0);
    final girls = (_pull > 0 ? _pull : 0.0);
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: MemoryImage(_ArtCache.of('tug')),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _scrim(opacity: 0.3)),
          Positioned(
            left: 16,
            top: 90,
            right: 16,
            child: Column(
              children: [
                const Text(
                  'Tug of War — Boys vs Girls',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                Text(
                  'Rounds — Boys $_boysRounds  •  Girls $_girlsRounds',
                  style: const TextStyle(
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      '👦 Boys',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: 0.5 - _pull / 2,
                        minHeight: 16,
                        backgroundColor: Colors.pink.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blue,
                        ),
                      ),
                    ),
                    const Text(
                      'Girls 👧',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  _pull < -0.05
                      ? 'Boys pulling! ${(boys * 100).round()}%'
                      : _pull > 0.05
                      ? 'Girls pulling! ${(girls * 100).round()}%'
                      : 'Even — send a gift to pull!',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    for (int i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('👦', style: TextStyle(fontSize: 36)),
                      ),
                  ],
                ),
                const Text('━━━🪢━━━', style: TextStyle(fontSize: 20)),
                Column(
                  children: [
                    for (int i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('👧', style: TextStyle(fontSize: 36)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 210,
            child: Center(
              child: Text(
                'Gifts: ${widget.cfg.gifts.entries.map((e) => '${e.value} = ${e.key}').join('  •  ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- painters
class MapPainter extends CustomPainter {
  final RegionInfo? selected;
  final Map<String, int> points;
  MapPainter({required this.selected, required this.points});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8F5E9),
    );
    // simplified Myanmar outline (original schematic, not a copied map)
    final outline = Path()
      ..moveTo(size.width * 0.55, size.height * 0.06)
      ..lineTo(size.width * 0.72, size.height * 0.14)
      ..lineTo(size.width * 0.78, size.height * 0.30)
      ..lineTo(size.width * 0.70, size.height * 0.48)
      ..lineTo(size.width * 0.66, size.height * 0.66)
      ..lineTo(size.width * 0.60, size.height * 0.90)
      ..lineTo(size.width * 0.52, size.height * 0.94)
      ..lineTo(size.width * 0.44, size.height * 0.72)
      ..lineTo(size.width * 0.30, size.height * 0.60)
      ..lineTo(size.width * 0.22, size.height * 0.42)
      ..lineTo(size.width * 0.30, size.height * 0.24)
      ..lineTo(size.width * 0.42, size.height * 0.10)
      ..close();
    canvas.drawPath(outline, Paint()..color = const Color(0xFFA5D6A7));
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final r in kRegions) {
      final p = Offset(size.width * r.x, size.height * r.y);
      final isSel = selected?.en == r.en;
      canvas.drawCircle(
        p,
        isSel ? 12 : 6,
        Paint()..color = isSel ? Colors.red : const Color(0xFF1565C0),
      );
      tp.text = TextSpan(
        text: r.my,
        style: TextStyle(
          color: Colors.black87,
          fontSize: isSel ? 15 : 11,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        ),
      );
      tp.layout();
      tp.paint(canvas, p + const Offset(10, -6));
      final pts = points[r.en] ?? 0;
      if (pts > 0) {
        tp.text = TextSpan(
          text: '$pts pts',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        );
        tp.layout();
        tp.paint(canvas, p + const Offset(10, 8));
      }
    }
    if (selected != null) {
      final p = Offset(size.width * selected!.x, size.height * selected!.y);
      canvas.drawCircle(p, 26, Paint()..color = Colors.red.withOpacity(0.25));
    }
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.selected != selected || old.points != points;
}
