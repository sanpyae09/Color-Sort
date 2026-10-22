import 'package:flutter/foundation.dart';

/// DIAGNOSTIC STUB (v1.0.2): the google_mobile_ads plugin is fully removed
/// from this build to isolate the launch crash. All ad calls are no-ops.
/// The real implementation is preserved in git history (v1.0.1 tree).
class Ads {
  Ads._();

  static const bool enabled = false;
  static const String bannerId = '';
  static const String interstitialId = '';
  static const String rewardedId = '';

  static Future<void> init() async {}

  static void loadInterstitial() {}

  static void loadRewarded() {}

  static bool get rewardedReady => false;

  static void maybeShowInterstitial(int roundsPlayed) {}

  /// No-op: always reports "no ad ready" so callers use their fallback.
  static bool showRewarded({required VoidCallback onReward}) => false;
}
