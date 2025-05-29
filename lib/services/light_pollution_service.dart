import 'package:geolocator/geolocator.dart';

class LightPollutionService {
  Future<Map<String, dynamic>> getLightPollutionData(Position position) async {
    // For now, return mock data
    // In a real implementation, you would fetch this from a light pollution API
    return {
      'bortleScale': 4,
      'description': 'Rural/suburban transition',
      'color': '#4CAF50',
    };
  }

  String getBortleDescription(int scale) {
    switch (scale) {
      case 1:
        return 'Excellent dark-sky site';
      case 2:
        return 'Typical truly dark site';
      case 3:
        return 'Rural sky';
      case 4:
        return 'Rural/suburban transition';
      case 5:
        return 'Suburban sky';
      case 6:
        return 'Bright suburban sky';
      case 7:
        return 'Suburban/urban transition';
      case 8:
        return 'City sky';
      case 9:
        return 'Inner-city sky';
      default:
        return 'Unknown';
    }
  }

  String getBortleColor(int scale) {
    switch (scale) {
      case 1:
        return '#000000';
      case 2:
        return '#1A1A1A';
      case 3:
        return '#333333';
      case 4:
        return '#4CAF50';
      case 5:
        return '#FFC107';
      case 6:
        return '#FF9800';
      case 7:
        return '#FF5722';
      case 8:
        return '#F44336';
      case 9:
        return '#D32F2F';
      default:
        return '#FFFFFF';
    }
  }
} 