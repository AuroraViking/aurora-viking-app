// lib/services/aurora_message_service.dart
import 'dart:ui';

class AuroraMessageService {
  /// Returns a descriptive message based on Kp index
  static String getKpMessage(double kp) {
    final kpInt = kp.round();

    if (kpInt == 0) return "Aurora might form low to the north if Bz goes negative";
    if (kpInt == 1) return "Aurora might form Low to the northern horizon";
    if (kpInt == 2) return "Aurora might form to the north";
    if (kpInt == 3) return "Aurora will form to the north if Bz is negative";
    if (kpInt == 4 || kpInt == 5) return "Aurora will form to the North and Overhead";
    if (kpInt >= 6 && kpInt <= 9) return "✨ Aurora can form anywhere - Let's dance to the disco lights!";

    return "Kp index not available";
  }

  /// Returns a descriptive message based on BzH value
  static String getBzHMessage(double bzH) {
    if (bzH > 6) return "✨ Strong aurora conditions – Get out now!";
    if (bzH > 4.5) return "Strong aurora likely in the next few hours";
    if (bzH > 3) return "Moderate aurora likely in the next few hours";
    if (bzH > 1.5) return "Faint aurora likely in the next few hours";
    if (bzH > 0) return "Weak aurora possible in the next hours";
    return "No aurora potential right now";
  }

  /// Returns a combined status message considering both Kp and BzH
  static String getCombinedAuroraMessage(double kp, double bzH) {
    final kpInt = kp.round();
    final bzHMessage = getBzHMessage(bzH);
    final kpMessage = getKpMessage(kp);

    // For high activity, emphasize the excitement
    if (bzH > 6 || kpInt >= 6) {
      return "🌟 EXCEPTIONAL AURORA CONDITIONS! $bzHMessage";
    }

    // For strong conditions, combine both factors
    if (bzH > 4.5 || kpInt >= 4) {
      return "⚡ STRONG AURORA ACTIVITY! $bzHMessage";
    }

    // For moderate conditions
    if (bzH > 3 || kpInt >= 3) {
      return "🌌 MODERATE AURORA LIKELY! $bzHMessage";
    }

    // For weak conditions
    if (bzH > 1.5 || kpInt >= 2) {
      return "✨ AURORA POSSIBLE! $bzHMessage";
    }

    // For minimal conditions
    if (bzH > 0 || kpInt >= 1) {
      return "💫 WEAK AURORA POTENTIAL. $bzHMessage";
    }

    // No aurora
    return "❌ NO AURORA EXPECTED. $bzHMessage";
  }

  /// Returns an appropriate color for the aurora status
  static Color getStatusColor(double kp, double bzH) {
    final kpInt = kp.round();

    // Strong conditions - bright colors
    if (bzH > 6 || kpInt >= 6) return const Color(0xFFFFD700); // Gold
    if (bzH > 4.5 || kpInt >= 4) return const Color(0xFFFF6B35); // Orange-red

    // Moderate conditions
    if (bzH > 3 || kpInt >= 3) return const Color(0xFF4ECDC4); // Teal

    // Weak conditions
    if (bzH > 1.5 || kpInt >= 2) return const Color(0xFF45B7D1); // Light blue
    if (bzH > 0 || kpInt >= 1) return const Color(0xFF96CEB4); // Light green

    // No aurora
    return const Color(0xFF95A5A6); // Gray
  }

  /// Returns aurora activity level as a string
  static String getActivityLevel(double kp, double bzH) {
    final kpInt = kp.round();

    if (bzH > 6 || kpInt >= 6) return "EXCEPTIONAL";
    if (bzH > 4.5 || kpInt >= 4) return "STRONG";
    if (bzH > 3 || kpInt >= 3) return "MODERATE";
    if (bzH > 1.5 || kpInt >= 2) return "WEAK";
    if (bzH > 0 || kpInt >= 1) return "MINIMAL";
    return "NONE";
  }

  /// Returns specific advice for aurora hunters
  static String getAuroraAdvice(double kp, double bzH) {
    final kpInt = kp.round();

    if (bzH > 6 || kpInt >= 6) {
      return "🚗 Drop everything and head out NOW! Conditions are exceptional. Aurora visible far south!";
    }

    if (bzH > 4.5 || kpInt >= 4) {
      return "📸 Get ready to head out! Strong aurora likely overhead in Iceland within hours.";
    }

    if (bzH > 3 || kpInt >= 3) {
      return "👀 Keep watching! Moderate aurora likely to the north. Good time to prepare equipment.";
    }

    if (bzH > 1.5 || kpInt >= 2) {
      return "🌙 Stay alert on clear nights. Faint aurora possible to the northern horizon.";
    }

    if (bzH > 0 || kpInt >= 1) {
      return "⏰ Monitor conditions. Weak aurora might appear if solar wind strengthens.";
    }

    return "😴 Rest easy tonight. No significant aurora activity expected.";
  }
}