import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobBannerCard extends StatefulWidget {
  final String? adUnitId;
  const AdMobBannerCard({super.key, this.adUnitId});

  @override
  State<AdMobBannerCard> createState() => _AdMobBannerCardState();
}

class _AdMobBannerCardState extends State<AdMobBannerCard> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  static const String _productionAdUnitId = 'ca-app-pub-4178524691208335/6625766838';

  @override
  void initState() {
    super.initState();
    final adUnitId = widget.adUnitId ?? _productionAdUnitId;
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() => _isLoaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Center(
          child: _bannerAd != null && _isLoaded
              ? SizedBox(
                  height: 100, // Make ad bigger, similar to post card
                  child: AdWidget(ad: _bannerAd!),
                )
              : Container(
                  height: 100,
                  alignment: Alignment.center,
                  child: const Text(
                    'Ad loading...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
        ),
      ),
    );
  }
}
