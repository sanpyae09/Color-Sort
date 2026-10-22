import 'package:flutter/material.dart';
import 'ads.dart';
import 'data.dart';
import 'home.dart';
import 'store.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Startup hardening: never let a slow/hung storage or asset load block the
  // first frame — the Android system splash must always hand over to the app.
  try {
    await Store.instance.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('QuizNova: store init failed: $e');
  }
  try {
    await QuestionBank.instance.load().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('QuizNova: question load failed: $e');
  }
  Ads.init();
  runApp(const QuizNovaApp());
}

class QuizNovaApp extends StatelessWidget {
  const QuizNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuizNova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Brand.blue),
        scaffoldBackgroundColor: Brand.bg,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      FadeSlideRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/splash_art.jpg', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Brand.blue.withValues(alpha: 0.10),
                  Colors.transparent,
                  Brand.navy.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 56),
                // Owl bounces in with an elastic scale, then keeps bobbing.
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: Bobbing(
                    child: Image.asset('assets/images/owl_mascot.png', width: 185, height: 185),
                  ),
                ),
                const SizedBox(height: 10),
                const FadeSlideIn(
                  delayMs: 250,
                  child: Text(
                    'QuizNova',
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5, shadows: [
                      Shadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 3)),
                    ]),
                  ),
                ),
                const FadeSlideIn(
                  delayMs: 400,
                  child: Text(
                    'Small Questions. Big Discoveries.',
                    style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                const FadeSlideIn(
                  delayMs: 550,
                  child: Text(
                    'Think  •  Learn  •  Grow',
                    style: TextStyle(fontSize: 14, color: Colors.white, letterSpacing: 2.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1600),
                      curve: Curves.easeInOut,
                      onEnd: _goHome,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.35),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Loading...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 34),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
