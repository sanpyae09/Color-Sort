import 'dart:async';

import 'package:flutter/material.dart';

import 'data.dart';
import 'home.dart';
import 'locations.dart';
import 'settings.dart';
import 'store.dart';
import 'vpn.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Startup hardening (QuizNova lesson): a hung storage/cache load must
  // never block the first frame — time-box every startup await.
  try {
    await AppStore.instance.init().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('SecureNet: store init failed: $e');
  }
  try {
    await ServerRepository.instance
        .loadCache()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('SecureNet: cache load failed: $e');
  }
  runApp(const SecureNetApp());
}

class SecureNetApp extends StatelessWidget {
  const SecureNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureNet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Brand.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Brand.bg0,
        useMaterial3: true,
      ),
      home: const SplashGate(),
    );
  }
}

/// Screen 1 (splash) → screen 2 (onboarding, first run) → app shell.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    final seen = AppStore.instance.seenOnboarding;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => seen ? const AppShell() : const OnboardingPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: Brand.screenGradient),
          // Earth horizon along the bottom, as in the design sheet.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/earth.jpg',
              height: 240,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Brand.bg0.withValues(alpha: 0.25),
                  Colors.transparent,
                  Brand.bg0.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 74),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Brand.blue.withValues(alpha: 0.55),
                          blurRadius: 46,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset('assets/images/app_icon.png',
                          width: 104, height: 104),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('SecureNet',
                    style: TextStyle(
                        color: Brand.text,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
                const SizedBox(height: 6),
                const Text('F a s t   ·   S a f e   ·   F r e e',
                    style: TextStyle(color: Brand.cyan, fontSize: 13.5)),
                const SizedBox(height: 22),
                const Text(
                  'Your privacy, our priority.\nAccess the internet without limits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Brand.textDim, height: 1.5),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeInOut,
                      onEnd: _finish,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 5,
                        backgroundColor: Brand.border,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Brand.cyan),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 44),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen 2 — first-run onboarding.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  Future<void> _start(BuildContext context) async {
    await AppStore.instance.setSeenOnboarding();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: Brand.screenGradient,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _start(context),
                  child: const Text('Skip',
                      style: TextStyle(color: Brand.textDim, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),
              // Shield illustration built from the app icon + orbit chips.
              SizedBox(
                width: 240,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 196,
                      height: 196,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Brand.blue.withValues(alpha: 0.13),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset('assets/images/app_icon.png',
                          width: 128, height: 128),
                    ),
                    const Positioned(
                        top: 6,
                        left: 18,
                        child: _OrbitIcon(icon: Icons.public)),
                    const Positioned(
                        top: 22,
                        right: 8,
                        child: _OrbitIcon(icon: Icons.wifi)),
                    const Positioned(
                        bottom: 14,
                        left: 4,
                        child: _OrbitIcon(icon: Icons.lock_outline)),
                    const Positioned(
                        bottom: 2,
                        right: 26,
                        child: _OrbitIcon(icon: Icons.speed)),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Browse Freely\nWithout Limits',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Brand.text,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.25),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 44),
                child: Text(
                  'Get secure access to any website, anywhere in the world — free, live servers, one tap.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Brand.textDim, height: 1.5),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(true),
                  _dot(false),
                  _dot(false),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
                child: PrimaryButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward,
                  onTap: () => _start(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(bool active) => Container(
        width: active ? 22 : 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: active ? Brand.blue : Brand.border,
          borderRadius: BorderRadius.circular(99),
        ),
      );
}

class _OrbitIcon extends StatelessWidget {
  final IconData icon;
  const _OrbitIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Brand.cardSoft,
        shape: BoxShape.circle,
        border: Border.all(color: Brand.border),
      ),
      child: Icon(icon, color: Brand.cyan, size: 20),
    );
  }
}

/// Tab shell: Home / Locations / Settings + kill-switch blocking overlay.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final vpn = VpnController.instance;
    return Scaffold(
      backgroundColor: Brand.bg0,
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomeScreen(onGoLocations: () => setState(() => _tab = 1)),
              const LocationsScreen(),
              const SettingsPage(),
            ],
          ),
          // Kill-switch overlay: shown while an unexpected drop is being
          // auto-reconnected with the kill switch enabled.
          AnimatedBuilder(
            animation: vpn,
            builder: (context, _) {
              if (!vpn.killSwitchBlock) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Brand.bg0.withValues(alpha: 0.94),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield,
                            color: Brand.amber, size: 62),
                        const SizedBox(height: 18),
                        const Text('Connection Lost',
                            style: TextStyle(
                                color: Brand.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            'Kill Switch is ON. Your traffic stays blocked while SecureNet reconnects you securely…',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Brand.textDim, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const CircularProgressIndicator(color: Brand.cyan),
                        const SizedBox(height: 26),
                        TextButton(
                          onPressed: () => vpn.cancelReconnect(),
                          child: const Text('Cancel & Disconnect',
                              style: TextStyle(
                                  color: Brand.red, fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        selectedItemColor: Brand.blue,
        unselectedItemColor: Brand.textDim,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.place_outlined), label: 'Locations'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
