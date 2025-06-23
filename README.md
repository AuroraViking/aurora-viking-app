# Aurora Viking App

Aurora Viking is a cross-platform Flutter app for aurora (northern lights) enthusiasts. It helps users track, capture, and share aurora sightings with a vibrant community, while providing real-time aurora forecasts and scientific data.

## Purpose
Aurora Viking connects aurora hunters, enabling them to:
- Spot and document aurora sightings with photos, intensity ratings, and descriptions.
- Share sightings on a community map and feed.
- Receive real-time alerts and notifications about aurora activity nearby.
- Engage with other users by liking, commenting, and confirming sightings.
- View user profiles, stats, and a gallery of aurora photos.
- Access aurora forecasts and scientific data (Kp index, BzH, solar wind, etc.).

## Main Features
- **Community Feed & Map:** See recent and nearby aurora sightings shared by users.
- **Spot & Share Aurora:** Capture photos, rate intensity, and submit sightings with location data.
- **Real-Time Alerts:** Get notified about aurora activity in your area based on live data and community reports.
- **User Profiles:** Track your sightings, verifications, and photo gallery.
- **Forecasts & Data:** View up-to-date aurora forecasts and scientific measurements to plan your aurora hunting.
- **Firebase & Supabase Integration:** Secure authentication, real-time updates, and cloud storage.
- **AdMob Monetization:** Banner ads are shown in the World, Nearby, and Forecast tabs using production ad units. No test ads are present in the production build.

## Privacy & Compliance
- Aurora Viking does **not** store or transmit any sensitive information beyond what is required for app functionality.
- No hardcoded secrets or test ad units are present in the production build.
- All user data is handled according to our [Privacy Policy](PRIVACY_POLICY.md).
- The app is compliant with Google Play and App Store policies.

## Getting Started

To run the app locally, make sure you have Flutter installed and configured. You will also need to set up environment variables for Firebase, Supabase, and Google Maps in a `.env` file (see `.env.example` if available).

For more information on Flutter development:
- [Flutter documentation](https://docs.flutter.dev/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

## Play Store Submission Checklist
- [x] All non-essential or non-functional features are hidden or disabled.
- [x] All ad units use production AdMob IDs (`ca-app-pub-4178524691208335/6625766838`).
- [x] No test ad units or hardcoded secrets present.
- [x] Privacy policy included and linked in the app and store listing.
- [x] App tested for crashes, UI bugs, and policy compliance.
- [x] Account deletion and privacy settings are functional.

## Contact
For support or questions, email: support@auroraviking.app
