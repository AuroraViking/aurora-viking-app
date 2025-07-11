import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AuroraNativeAdCard extends StatefulWidget {
  final bool testMode;
  const AuroraNativeAdCard({super.key, this.testMode = false});

  @override
  State<AuroraNativeAdCard> createState() => _AuroraNativeAdCardState();
}

class _AuroraNativeAdCardState extends State<AuroraNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  // static const String _testAdUnitId = 'ca-app-pub-3940256099942544/2247696110'; // Google's test native ad unit
  // TODO: When enabling native ads, use the production ad unit ID here.

  @override
  void initState() {
    super.initState();
    // Native ads are currently disabled in production. Uncomment and set production ad unit ID to enable.
    // _nativeAd = NativeAd(
    //   adUnitId: '<YOUR_PRODUCTION_NATIVE_AD_UNIT_ID>',
    //   factoryId: 'listTile',
    //   request: const AdRequest(),
    //   listener: NativeAdListener(
    //     onAdLoaded: (ad) => setState(() => _isLoaded = true),
    //     onAdFailedToLoad: (ad, error) {
    //       ad.dispose();
    //       setState(() => _isLoaded = false);
    //     },
    //   ),
    // )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const SizedBox.shrink();
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: SizedBox(
        height: 180,
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
