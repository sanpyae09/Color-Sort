import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  SharedPreferences? _prefs;

  int coins = 0;
  int xp = 0;
  int totalAnswered = 0;
  int totalCorrect = 0;
  int roundsPlayed = 0;
  int bestRound = 0; // best correct count in a single round
  int streak = 0;
  bool soundOn = true;
  String lastPlayDate = '';
  String dailyDoneDate = '';
  Set<int> seenIds = {};

  static String dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get level => xp ~/ 250 + 1;
  int get xpInLevel => xp % 250;
  double get accuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  String get levelTitle {
    const titles = ['Brain Starter', 'Brain Learner', 'Quiz Explorer', 'Trivia Master', 'Grand Master'];
    final i = (level - 1).clamp(0, titles.length - 1);
    return titles[i];
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    coins = p.getInt('coins') ?? 0;
    xp = p.getInt('xp') ?? 0;
    totalAnswered = p.getInt('totalAnswered') ?? 0;
    totalCorrect = p.getInt('totalCorrect') ?? 0;
    roundsPlayed = p.getInt('roundsPlayed') ?? 0;
    bestRound = p.getInt('bestRound') ?? 0;
    streak = p.getInt('streak') ?? 0;
    soundOn = p.getBool('soundOn') ?? true;
    lastPlayDate = p.getString('lastPlayDate') ?? '';
    dailyDoneDate = p.getString('dailyDoneDate') ?? '';
    seenIds = (p.getStringList('seenIds') ?? []).map(int.parse).toSet();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setInt('coins', coins);
    await p.setInt('xp', xp);
    await p.setInt('totalAnswered', totalAnswered);
    await p.setInt('totalCorrect', totalCorrect);
    await p.setInt('roundsPlayed', roundsPlayed);
    await p.setInt('bestRound', bestRound);
    await p.setInt('streak', streak);
    await p.setBool('soundOn', soundOn);
    await p.setString('lastPlayDate', lastPlayDate);
    await p.setString('dailyDoneDate', dailyDoneDate);
    await p.setStringList('seenIds', seenIds.map((e) => e.toString()).toList());
  }

  /// Mark a question as seen without affecting answer stats (used by Skip).
  void markSeen(int questionId) {
    seenIds.add(questionId);
    _save();
  }

  void recordAnswer(int questionId, bool correct) {
    totalAnswered++;
    if (correct) totalCorrect++;
    seenIds.add(questionId);
    _save();
    notifyListeners();
  }

  /// Called when a round finishes. Handles coins/XP, best round, streak, daily flag.
  Future<void> recordRound({required int correctCount, required int coinsEarned, required int xpEarned, required bool isDaily}) async {
    roundsPlayed++;
    coins += coinsEarned;
    xp += xpEarned;
    if (correctCount > bestRound) bestRound = correctCount;
    final today = DateTime.now();
    final t = dateStr(today);
    if (isDaily) dailyDoneDate = t;
    if (lastPlayDate != t) {
      final yesterday = dateStr(today.subtract(const Duration(days: 1)));
      streak = (lastPlayDate == yesterday) ? streak + 1 : 1;
      lastPlayDate = t;
    }
    await _save();
    notifyListeners();
  }

  void addCoins(int n) {
    coins += n;
    _save();
    notifyListeners();
  }

  void setSound(bool v) {
    soundOn = v;
    _save();
    notifyListeners();
  }

  Future<void> resetAll() async {
    coins = 0;
    xp = 0;
    totalAnswered = 0;
    totalCorrect = 0;
    roundsPlayed = 0;
    bestRound = 0;
    streak = 0;
    lastPlayDate = '';
    dailyDoneDate = '';
    seenIds = {};
    await _prefs?.clear();
    await _save();
    notifyListeners();
  }
}
