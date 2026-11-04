import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';

// ---------------- Progress (local, no account, no server) ----------------
class Store extends ChangeNotifier {
  SharedPreferences? _prefs;
  String langCode = 'en';
  String userName = 'Learner';
  bool darkTheme = false;
  bool notificationsOn = true;
  bool autoPlayAudio = true;
  String reminderTime = '8:00 PM';
  final Set<String> doneCourses = <String>{};
  int studyMinutes = 0;
  final Map<String, int> dayMinutes = <String, int>{}; // Mon..Sun -> minutes

  int get lessonsDone => doneCourses.length;
  int get progressPct {
    if (courses.isEmpty) return 0;
    final v = (lessonsDone * 100 / courses.length).round();
    return v > 100 ? 100 : v;
  }

  int get streakDays {
    // v1 honest streak: days this week with study, counted from stored map.
    var n = 0;
    for (final v in dayMinutes.values) {
      if (v > 0) n++;
    }
    return n;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    langCode = _prefs!.getString('langCode') ?? 'en';
    userName = _prefs!.getString('userName') ?? 'Learner';
    darkTheme = _prefs!.getBool('darkTheme') ?? false;
    notificationsOn = _prefs!.getBool('notificationsOn') ?? true;
    autoPlayAudio = _prefs!.getBool('autoPlayAudio') ?? true;
    reminderTime = _prefs!.getString('reminderTime') ?? '8:00 PM';
    doneCourses.addAll(_prefs!.getStringList('doneCourses') ?? <String>[]);
    studyMinutes = _prefs!.getInt('studyMinutes') ?? 0;
    final days = _prefs!.getStringList('dayMinutes') ?? <String>[];
    for (final d in days) {
      final parts = d.split('=');
      if (parts.length == 2) dayMinutes[parts[0]] = int.tryParse(parts[1]) ?? 0;
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('langCode', langCode);
    await p.setString('userName', userName);
    await p.setBool('darkTheme', darkTheme);
    await p.setBool('notificationsOn', notificationsOn);
    await p.setBool('autoPlayAudio', autoPlayAudio);
    await p.setString('reminderTime', reminderTime);
    await p.setStringList('doneCourses', doneCourses.toList());
    await p.setInt('studyMinutes', studyMinutes);
    await p.setStringList(
        'dayMinutes', dayMinutes.entries.map((e) => '${e.key}=${e.value}').toList());
  }

  Future<void> setLang(String code) async {
    langCode = code;
    await _save();
    notifyListeners();
  }

  Future<void> setName(String name) async {
    userName = name.trim().isEmpty ? 'Learner' : name.trim();
    await _save();
    notifyListeners();
  }

  Future<void> toggleDark(bool v) async {
    darkTheme = v;
    await _save();
    notifyListeners();
  }

  Future<void> toggleNotifications(bool v) async {
    notificationsOn = v;
    await _save();
    notifyListeners();
  }

  Future<void> toggleAutoPlay(bool v) async {
    autoPlayAudio = v;
    await _save();
    notifyListeners();
  }

  Future<void> setReminder(String t) async {
    reminderTime = t;
    await _save();
    notifyListeners();
  }

  Future<void> completeCourse(String id, int minutes) async {
    doneCourses.add(id);
    studyMinutes += minutes;
    final day = _weekday();
    dayMinutes[day] = (dayMinutes[day] ?? 0) + minutes;
    await _save();
    notifyListeners();
  }

  Future<void> addStudyMinutes(int minutes) async {
    studyMinutes += minutes;
    final day = _weekday();
    dayMinutes[day] = (dayMinutes[day] ?? 0) + minutes;
    await _save();
    notifyListeners();
  }

  String _weekday() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[DateTime.now().weekday - 1];
  }
}

// ---------------- Text to speech (phone TTS, works offline) ----------------
class TtsService {
  // Same init-order rule as ListenPlayer: no platform object at import
  // time. The FlutterTts instance is created on first use, after
  // WidgetsFlutterBinding is ready.
  FlutterTts? _ttsInstance;
  FlutterTts get _tts => _ttsInstance ??= FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> speak(String text, String langCode) async {
    if (!_ready) await init();
    try {
      await _tts.stop();
      await _tts.setLanguage(langCode == 'ms' ? 'ms-MY' : 'en-US');
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

final tts = TtsService();

// ---------------- Screen-off listening ----------------
// This is the feature the user asked for explicitly: a real media
// playback service (just_audio_background). The lesson MP3s are
// bundled assets, so playback is a normal Android media session:
// it keeps playing when the screen locks, it appears on the lock
// screen with play/pause/next/previous, and earphone buttons work.
// It is NOT a timer that stops when the app sleeps, and it is NOT
// flutter_tts spoken from the UI thread.
class ListenPlayer {
  // SYSTEMATIC FIX: JustAudioBackground.init() in main() MUST run before
  // any AudioPlayer exists. Creating the player at import time (as a
  // top-level final) would break that order, so the player is created
  // lazily on first use, long after main() has initialised the
  // background service.
  AudioPlayer? _player;
  AudioPlayer get player => _player ??= AudioPlayer();
  ListenLesson? current;
  bool _prepared = false;

  // White-screen fix companion (v1.1): main() now inits the audio
  // background service in the background AFTER runApp, so Listen Mode
  // must not create/play before that init has had its chance. The
  // player waits at most 5s for the ready signal, then plays anyway.
  final Completer<void> _audioReady = Completer<void>();
  void markAudioReady() {
    if (!_audioReady.isCompleted) _audioReady.complete();
  }

  Future<void> _waitAudioReady() async {
    try {
      await _audioReady.future.timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Stream<PlayerState> get stateStream => player.playerStateStream;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;

  Future<void> playLesson(ListenLesson lesson) async {
    await _waitAudioReady();
    try {
      if (current?.id != lesson.id || !_prepared) {
        await player.setAudioSource(
          AudioSource.asset(
            lesson.asset,
            tag: MediaItem(
              id: lesson.id,
              title: lesson.title,
              artist: 'NUVESSA',
              album: 'Listening Lessons',
            ),
          ),
        );
        current = lesson;
        _prepared = true;
      }
      await player.play();
    } catch (_) {}
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> stop() async {
    await player.stop();
    _prepared = false;
    current = null;
  }

  Future<void> seek(Duration d) async {
    await player.seek(d);
  }
}

final listenPlayer = ListenPlayer();
