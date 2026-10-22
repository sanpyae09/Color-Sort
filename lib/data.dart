import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Question {
  final int id;
  final String cat;
  final String diff;
  final String q;
  final List<String> a;
  final int correct; // 1..4
  final String fact;
  const Question({required this.id, required this.cat, required this.diff, required this.q, required this.a, required this.correct, required this.fact});

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as int,
        cat: j['cat'] as String,
        diff: (j['diff'] ?? 'easy') as String,
        q: j['q'] as String,
        a: (j['a'] as List).map((e) => e.toString()).toList(),
        correct: j['correct'] as int,
        fact: (j['fact'] ?? '') as String,
      );
}

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;
  const CategoryInfo(this.name, this.icon, this.color);
}

const List<CategoryInfo> kCategories = [
  CategoryInfo('General Knowledge', Icons.public, Color(0xFF2563EB)),
  CategoryInfo('Science', Icons.science, Color(0xFF16A34A)),
  CategoryInfo('History', Icons.account_balance, Color(0xFFD97706)),
  CategoryInfo('Geography', Icons.map, Color(0xFF0D9488)),
  CategoryInfo('Space & Astronomy', Icons.rocket_launch, Color(0xFF7C3AED)),
  CategoryInfo('Animals', Icons.pets, Color(0xFFE11D48)),
  CategoryInfo('Movies & TV', Icons.movie, Color(0xFF4F46E5)),
  CategoryInfo('Sports', Icons.emoji_events, Color(0xFFEA580C)),
];

CategoryInfo categoryInfo(String name) =>
    kCategories.firstWhere((c) => c.name == name, orElse: () => kCategories.first);

class QuestionBank {
  QuestionBank._();
  static final QuestionBank instance = QuestionBank._();
  List<Question> _all = [];
  bool loaded = false;

  Future<void> load() async {
    if (loaded) return;
    final raw = await rootBundle.loadString('assets/questions.json');
    final list = json.decode(raw) as List;
    _all = list.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
    loaded = true;
  }

  List<Question> get all => _all;

  int countFor(String cat) => _all.where((q) => q.cat == cat).length;

  /// Pick [count] questions from [pool], preferring ids not in [seen].
  /// If the unseen pool runs dry, that pool's seen ids are recycled.
  List<Question> pick(List<Question> pool, int count, Set<int> seen, Random rng) {
    var unseen = pool.where((q) => !seen.contains(q.id)).toList()..shuffle(rng);
    if (unseen.length < count) {
      final need = count - unseen.length;
      final recycled = pool.where((q) => seen.contains(q.id)).toList()..shuffle(rng);
      unseen = [...unseen, ...recycled.take(need)];
    }
    return unseen.take(count).toList();
  }

  List<Question> forCategory(String cat, int count, Set<int> seen) =>
      pick(_all.where((q) => q.cat == cat).toList(), count, seen, Random());

  List<Question> mixed(int count, Set<int> seen) => pick(_all, count, seen, Random());

  /// Daily challenge: 5 questions, same for everyone on a given date.
  List<Question> daily(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    final rng = Random(seed);
    final copy = [..._all]..shuffle(rng);
    return copy.take(5).toList();
  }
}
