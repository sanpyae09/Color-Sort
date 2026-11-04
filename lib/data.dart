// NUVESSA v1 content: English + Bahasa Malaysia first.
// Every phrase carries its Burmese meaning, because the first
// learners are Myanmar speakers. Other languages in the UI are
// shown as "Soon" - they have no fake content behind them.

class Lang {
  final String code; // en, ms
  final String name;
  final String flag;
  final String ttsLocale; // flutter_tts locale
  final String sttLocale; // speech_to_text locale
  final String greeting;
  const Lang(this.code, this.name, this.flag, this.ttsLocale, this.sttLocale,
      this.greeting);
}

const english = Lang('en', 'English', '🇺🇸', 'en-US', 'en_US', 'Hello!');
const malay = Lang('ms', 'Bahasa Malaysia', '🇲🇾', 'ms-MY', 'ms_MY', 'Selamat datang!');

class Phrase {
  final String en;
  final String ms;
  final String my; // Burmese meaning
  const Phrase(this.en, this.ms, this.my);
  String inLang(String code) => code == 'ms' ? ms : en;
}

const phrases = <Phrase>[
  Phrase('Good morning', 'Selamat pagi', 'မင်္ဂလာနံနက်ခင်း'),
  Phrase('How are you?', 'Apa khabar?', 'နေကောင်းလား'),
  Phrase('I am fine, thank you.', 'Saya baik, terima kasih.', 'ကျွန်တော် နေကောင်းပါတယ်၊ ကျေးဇူးတင်ပါတယ်'),
  Phrase('What is your name?', 'Siapa nama anda?', 'ခင်ဗျားနာမည်က ဘာလဲ'),
  Phrase('My name is Alex.', 'Nama saya Alex.', 'ကျွန်တော့်နာမည် Alex ပါ'),
  Phrase('Where are you from?', 'Dari mana anda berasal?', 'ခင်ဗျား ဘယ်ကလာတာလဲ'),
  Phrase('Nice to meet you.', 'Gembira bertemu dengan anda.', 'တွေ့ရတာ ဝမ်းသာပါတယ်'),
  Phrase('Thank you very much.', 'Terima kasih banyak-banyak.', 'အများကြီး ကျေးဇူးတင်ပါတယ်'),
  Phrase('Excuse me.', 'Maafkan saya.', 'ခွင့်လွှတ်ပါ / တောင်းပန်ပါတယ်'),
  Phrase('See you tomorrow.', 'Jumpa lagi esok.', 'မနက်ဖြန် ပြန်တွေ့မယ်'),
  Phrase('I do not understand.', 'Saya tidak faham.', 'ကျွန်တော် နားမလည်ဘူး'),
  Phrase('Please speak slowly.', 'Tolong cakap perlahan-lahan.', 'ဖြည်းဖြည်းလေး ပြောပေးပါ'),
  Phrase('How much is this?', 'Berapa harga ini?', 'ဒါ ဘယ်လောက်လဲ'),
  Phrase('Where is the toilet?', 'Di mana tandas?', 'အိမ်သာ ဘယ်မှာလဲ'),
  Phrase('I love Malaysia.', 'Saya suka Malaysia.', 'ကျွန်တော် မလေးရှားကို ချစ်တယ်'),
];

class Course {
  final String id;
  final String langCode;
  final String title;
  final String subtitle;
  final String learners;
  final String tag; // Popular / Business / Travel
  final int color; // gradient start
  final int color2;
  const Course(this.id, this.langCode, this.title, this.subtitle,
      this.learners, this.tag, this.color, this.color2);
}

const courses = <Course>[
  Course('en-everyday', 'en', 'English for Everyday Life',
      'Start speaking with confidence!', '1.2M learners', 'Popular',
      0xFF7C3AED, 0xFF2563EB),
  Course('ms-everyday', 'ms', 'Bahasa Malaysia for Everyday Life',
      'Cakap Melayu dengan yakin!', '480K learners', 'Popular',
      0xFF059669, 0xFF0EA5E9),
  Course('en-travel', 'en', 'English for Travel',
      'At the airport, hotel and market.', '860K learners', 'Travel',
      0xFFDB2777, 0xFFF59E0B),
  Course('ms-travel', 'ms', 'Bahasa Malaysia for Travel',
      'Di lapangan terbang dan pasar.', '310K learners', 'Travel',
      0xFFEA580C, 0xFF16A34A),
  Course('en-work', 'en', 'English for Work',
      'Meetings, email and interviews.', '740K learners', 'Business',
      0xFF4F46E5, 0xFF7C3AED),
  Course('ms-work', 'ms', 'Bahasa Malaysia for Work',
      'Mesyuarat dan temuduga kerja.', '260K learners', 'Business',
      0xFF0D9488, 0xFF2563EB),
];

class QuizQ {
  final String prompt; // word shown
  final String promptLang; // en or ms
  final String answer; // correct translation
  final List<String> options;
  const QuizQ(this.prompt, this.promptLang, this.answer, this.options);
}

// 10 questions per course: alternate direction, options are other
// phrases in the target language so a wrong answer is still a real word.
List<QuizQ> quizFor(Course course) {
  final target = course.langCode;
  final other = target == 'en' ? 'ms' : 'en';
  final qs = <QuizQ>[];
  for (var i = 0; i < 10; i++) {
    final p = phrases[i];
    // Even index: show other-language word, pick target word.
    // Odd index: show target-language word, pick other-language word.
    final showOther = i.isEven;
    final shown = showOther ? p.inLang(other) : p.inLang(target);
    final shownLang = showOther ? other : target;
    final correct = showOther ? p.inLang(target) : p.inLang(other);
    final pool = phrases
        .where((x) => x.inLang(showOther ? target : other) != correct)
        .map((x) => x.inLang(showOther ? target : other))
        .toList();
    final opts = <String>[correct, pool[0], pool[1], pool[2]];
    opts.shuffle();
    qs.add(QuizQ(shown, shownLang, correct, opts));
  }
  return qs;
}

class ListenLesson {
  final String id;
  final String langCode;
  final String title;
  final String subtitle;
  final String asset;
  final List<Phrase> lines;
  const ListenLesson(
      this.id, this.langCode, this.title, this.subtitle, this.asset, this.lines);
}

const listenLessons = <ListenLesson>[
  ListenLesson('listen-en', 'en', 'English Everyday Listening',
      '10 phrases, spoken twice. Plug in earphones, lock the phone, just listen.',
      'assets/audio/listen_en_everyday.mp3', phrases),
  ListenLesson('listen-ms', 'ms', 'Bahasa Malaysia Everyday Listening',
      '10 frasa, disebut dua kali. Pasang fon telinga, kunci telefon, dengar sahaja.',
      'assets/audio/listen_ms_everyday.mp3', phrases),
];

// Translation dictionary: exact-phrase lookup EN <-> MS.
String? translateLookup(String input, String from, String to) {
  final q = input.trim().toLowerCase();
  for (final p in phrases) {
    if (from == 'en' && p.en.toLowerCase() == q) return to == 'ms' ? p.ms : p.my;
    if (from == 'ms' && p.ms.toLowerCase() == q) return to == 'en' ? p.en : p.my;
  }
  // Partial match: the input contains a known phrase.
  for (final p in phrases) {
    final src = from == 'en' ? p.en.toLowerCase() : p.ms.toLowerCase();
    if (q.contains(src) || src.contains(q)) {
      return to == 'ms' ? p.ms : (to == 'en' ? p.en : p.my);
    }
  }
  return null;
}

String myMeaningOf(String text, String langCode) {
  for (final p in phrases) {
    if (p.inLang(langCode) == text) return p.my;
  }
  return '';
}
