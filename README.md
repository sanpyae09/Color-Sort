# NUVESSA v1.0.0

Learn Every Language. Unlock Every World.
English + Bahasa Malaysia first, from the user's sent 10-screen UI mockup.

## Screens (matching the mockup layout)
Splash, Home (language grid, progress ring, Listen Mode card),
Courses / Explore (All / Popular / Business / Travel filters),
Lesson quiz (10 questions, speak + Burmese hint),
Speaking Practice (mic + speech recognition),
Translation (EN ⇄ MS, Copy / Share / Listen),
AI Conversation (offline scripted replies, topic chips),
My Progress (ring, lessons / minutes / streak, weekly bars),
Profile (editable name, achievements, goals),
Settings (language, theme, notifications, daily reminder, auto-play audio).

## Screen-off listening — how it really works
Listen Mode is NOT UI-thread TTS. It uses `just_audio_background`:
a real Android media session, so the bundled lesson MP3s keep playing
when the phone locks, appear on the lock screen with play/pause
controls, and earphone buttons work. Android manifest (via
`ci/post_scaffold.py`) adds FOREGROUND_SERVICE +
FOREGROUND_SERVICE_MEDIA_PLAYBACK + POST_NOTIFICATIONS.

Lessons: `assets/audio/listen_en_everyday.mp3` (53s, 10 phrases x2)
and `listen_ms_everyday.mp3` (64s, 10 phrases x2).

## v1 honesty notes
- Other languages in the grid (Spanish, French, German, Japanese,
  Chinese, Korean) show "Soon" — no fake content behind them.
- Progress starts at 0 (not the mockup's 68%) and grows from real use.
- AI Conversation is offline and scripted in v1 (no API key, no server).
- Listen-lesson audio is TTS-generated prototype audio. Replace with
  licensed / native-speaker recordings before any public Play Store release.
- Translation v1 covers the everyday phrases bundled in `lib/data.dart`.

## Build (proven SecureNet/QuizNova route)
Branch `nuvessa` of sanpyae09/Color-Sort. Files: pubspec.yaml, lib/,
assets/audio/, assets/images/ (icon, via assets_b64 in CI),
ci/post_scaffold.py, ci/build.yml.txt -> .github/workflows/build.yml
in the browser step (connector workflow writes are 403, as before).
App ID: com.pyaystudios.nuvessa. Release tag: nuvessa-v1, asset nuvessa.apk.
