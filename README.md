# Aurora Viking App 🌌

[![Flutter](https://img.shields.io/badge/Flutter-3.24.0+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.5.0+-blue.svg)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey.svg)](https://flutter.dev/)

A comprehensive cross-platform Flutter application for aurora (northern lights) enthusiasts. Aurora Viking helps users track, capture, and share aurora sightings with a vibrant community while providing real-time aurora forecasts and scientific data.

## 🌟 Features

### 🔍 Aurora Detection & Sharing
- **Spot & Share Aurora**: Capture photos, rate intensity, and submit sightings with precise location data
- **Community Feed**: View recent aurora sightings shared by users worldwide
- **Interactive Map**: Explore aurora sightings on an interactive map with filtering options
- **Photo Gallery**: Personal gallery of your aurora captures with metadata

### 📊 Real-Time Data & Forecasts
- **Aurora Forecasts**: Up-to-date Kp index predictions and aurora activity forecasts
- **Solar Wind Data**: Real-time solar wind speed, density, and magnetic field measurements
- **Cloud Cover Analysis**: Cloud coverage forecasts to optimize aurora hunting
- **Moon Phase Tracking**: Moon phase information for optimal viewing conditions
- **Light Pollution Maps**: Bortle scale integration for dark sky locations

### 🔔 Smart Notifications
- **Aurora Alerts**: Real-time notifications about aurora activity in your area
- **Substorm Alerts**: Geomagnetic substorm notifications
- **Customizable Settings**: Configure notification preferences and frequency
- **Location-Based Alerts**: Get notified when aurora is visible near your location

### 👥 Community Features
- **User Profiles**: Detailed profiles with statistics, achievements, and photo galleries
- **Social Interactions**: Like, comment, and verify aurora sightings
- **Community Verification**: Crowd-sourced verification of aurora reports
- **Leaderboards**: Track top aurora hunters and contributors

### 🛒 E-commerce Integration
- **Aurora Tours**: Browse and book aurora hunting tours
- **Photo Prints**: Order high-quality prints of your aurora photos
- **Stripe Payments**: Secure payment processing for tours and prints
- **Tour Verification**: Authenticate tour bookings and experiences

### 📱 Advanced Features
- **Camera Integration**: Built-in camera with aurora detection algorithms
- **Offline Support**: Core features work without internet connection
- **Multi-language Support**: English and Icelandic localization
- **Dark Mode**: Optimized dark theme for night-time aurora hunting
- **AdMob Integration**: Monetization through banner advertisements

## 🛠️ Technology Stack

### Core Framework
- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **Material Design 3**: Modern UI components

### Backend Services
- **Firebase**: Authentication, Firestore database, Cloud Storage, Analytics
- **Supabase**: Real-time database and backend services
- **Google Maps**: Location services and mapping
- **Stripe**: Payment processing

### Data Sources
- **NOAA**: Solar wind and space weather data
- **Aurora Service**: Real-time aurora forecasts
- **Weather APIs**: Cloud cover and weather data
- **Bokun**: Tour booking integration

### Key Dependencies
```yaml
# Core UI & Charts
fl_chart: ^0.69.0
lottie: ^3.1.2

# Backend & Database
firebase_core: ^3.13.1
supabase_flutter: ^2.3.4
cloud_firestore: ^5.6.8

# Location & Maps
google_maps_flutter: ^2.5.3
geolocator: ^10.1.1

# Camera & Media
camera: ^0.11.1
image_picker: ^1.1.2

# Payments
flutter_stripe: ^11.5.0

# Notifications
flutter_local_notifications: ^19.3.0

# Ads
google_mobile_ads: ^6.0.0
```

## 📱 Screenshots

*[Screenshots would be added here]*

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.24.0 or higher)
- Dart SDK (3.5.0 or higher)
- Android Studio / VS Code
- iOS development tools (for iOS builds)
- Firebase project setup
- Supabase project setup

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/aurora_viking_app.git
   cd aurora_viking_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Configuration**
   Create a `.env` file in the project root with the following variables:
   ```env
   # Google Maps
   GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   
   # Supabase
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   
   # Firebase
   FIREBASE_API_KEY=your_firebase_api_key
   FIREBASE_APP_ID=your_firebase_app_id
   FIREBASE_MESSAGING_SENDER_ID=your_sender_id
   FIREBASE_PROJECT_ID=your_project_id
   FIREBASE_STORAGE_BUCKET=your_storage_bucket
   ```

4. **Platform-specific setup**

   **Android:**
   - Update `android/app/build.gradle.kts` with your application ID
   - Add Google Maps API key to `android/app/src/main/AndroidManifest.xml`

   **iOS:**
   - Update bundle identifier in Xcode
   - Add required permissions to `ios/Runner/Info.plist`

5. **Run the app**
   ```bash
   flutter run
   ```

### Build for Production

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── l10n/                     # Localization files
├── models/                   # Data models
├── providers/                # State management
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── forecast_tab.dart
│   ├── camera_aurora_screen.dart
│   ├── aurora_alerts_tab.dart
│   └── ...
├── services/                 # Business logic & API calls
│   ├── firebase_service.dart
│   ├── aurora_prediction_service.dart
│   ├── weather_service.dart
│   └── ...
└── widgets/                  # Reusable UI components
    ├── aurora_map.dart
    ├── forecast/
    ├── tour/
    └── ...
```

## 🔧 Configuration

### Firebase Setup
1. Create a Firebase project
2. Enable Authentication, Firestore, Storage, and Analytics
3. Download and add configuration files
4. Set up security rules for Firestore and Storage

### Supabase Setup
1. Create a Supabase project
2. Configure database tables and policies
3. Set up real-time subscriptions
4. Configure authentication providers

### Google Maps
1. Create a Google Cloud project
2. Enable Maps SDK for Android/iOS
3. Generate API keys with appropriate restrictions

### Stripe Integration
1. Create a Stripe account
2. Configure webhook endpoints
3. Set up product catalog for tours and prints

## 🧪 Testing

Run the test suite:
```bash
flutter test
```

Run with coverage:
```bash
flutter test --coverage
```

## 📦 Deployment

### Google Play Store
- [x] Production ad units configured
- [x] Privacy policy included
- [x] Account deletion functionality
- [x] Policy compliance verified

### App Store
- [x] iOS-specific configurations
- [x] App Store Connect setup
- [x] Privacy labels configured

## 🔒 Privacy & Security

- **Data Protection**: All user data is encrypted and stored securely
- **Privacy Policy**: Comprehensive privacy policy available at `PRIVACY_POLICY.md`
- **GDPR Compliance**: User data handling follows GDPR guidelines
- **Account Deletion**: Users can delete their accounts and associated data
- **No Sensitive Data**: No hardcoded secrets or sensitive information in code

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Email**: support@auroraviking.app
- **Documentation**: [Aurora Viking Docs](https://docs.auroraviking.app)
- **Issues**: [GitHub Issues](https://github.com/yourusername/aurora_viking_app/issues)

## 🙏 Acknowledgments

- NOAA for space weather data
- Aurora Service for forecast data
- Flutter team for the amazing framework
- The aurora hunting community for inspiration and feedback

## 📊 App Statistics

- **Platforms**: Android, iOS, Web, Desktop
- **Languages**: English, Icelandic
- **Database**: Firebase Firestore + Supabase
- **Real-time Features**: Live aurora alerts, community feed
- **Monetization**: AdMob banner ads, tour bookings, photo prints

---

**Made with ❤️ for the aurora hunting community**

*Capture the magic of the northern lights with Aurora Viking*
