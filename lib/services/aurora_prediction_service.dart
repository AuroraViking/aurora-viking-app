class AuroraPredictionService {
  static double calculateBzH(List<double> bzValues) {
    final recent = bzValues.takeLast(60);
    final sum = recent.where((bz) => bz < 0).fold(0.0, (acc, bz) => acc + (-bz / 60));
    return double.parse(sum.toStringAsFixed(2));
  }

  static String getBzMessage(double bzH) {
    if (bzH > 6) return "✨ Strong aurora conditions – Get out now!";
    if (bzH > 4.5) return "Strong aurora likely";
    if (bzH > 3) return "Moderate aurora likely";
    if (bzH > 1.5) return "Faint aurora possible";
    if (bzH > 0) return "Weak aurora potential";
    return "No aurora potential";
  }

  static String getKpMessage(int? kp) {
    if (kp == null) return "Kp data not available";
    if (kp >= 6) return "Aurora visible far south";
    if (kp >= 4) return "Aurora overhead in Iceland";
    if (kp >= 2) return "Aurora to the north";
    return "Low aurora chance";
  }
}

extension TakeLast<T> on List<T> {
  List<T> takeLast(int count) => skip(length - count).toList();
}
