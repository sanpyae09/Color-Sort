import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob wiring with Google's OFFICIAL TEST ad unit IDs only.
/// Never swap in real IDs in this MVP build.
class Ads {
  Ads._();
  static const String bannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedId = 'ca-app-pub-3940256099942544/5224354917';

  static final DateTime appStart = DateTime.now();
  static InterstitialAd? _interstitial;
  static RewardedAd? _rewarded;
  static bool _loadingInterstitial = false;
  static bool _loadingRewarded = false;

  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      loadInterstitial();
      loadRewarded();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  static void loadInterstitial() {
    if (_loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  static void loadRewarded() {
    if (_loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (_) {
          _rewarded = null;
          _loadingRewarded = false;
        },
      ),
    );
  }

  static bool get rewardedReady => _rewarded != null;

  /// Show an interstitial after every 3rd completed round,
  /// but never during the first 60 seconds after app launch.
  static void maybeShowInterstitial(int roundsPlayed) {
    if (roundsPlayed <= 0 || roundsPlayed % 3 != 0) return;
    if (DateTime.now().difference(appStart).inSeconds < 60) return;
    final ad = _interstitial;
    if (ad == null) {
      loadInterstitial();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadInterstitial();
      },
    );
    ad.show();
  }

  /// Show a rewarded ad. [onReward] fires only when the user actually
  /// earns the reward. Returns false when no ad is ready yet.
  static bool showRewarded({required VoidCallback onReward}) {
    final ad = _rewarded;
    if (ad == null) {
      loadRewarded();
      return false;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => onReward());
    return true;
  }
}
