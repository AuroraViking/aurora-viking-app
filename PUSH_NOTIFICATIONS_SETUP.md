# Push Notifications Setup Guide

## Overview
This guide explains how to deploy the Cloud Functions that enable push notifications for aurora sightings.

## What's Implemented

### Cloud Functions (functions/index.js)
1. **`onAuroraSightingCreated`** - Automatically triggers when new aurora sightings are posted
2. **`checkHighActivity`** - HTTP endpoint to check for high aurora activity
3. **`updateUserLocation`** - HTTP endpoint to update user location
4. **`helloWorld`** - Test function

### Features
- **50km radius notifications** - Users within 50km of an aurora sighting get notified
- **High activity alerts** - Notifications when 5+ sightings occur in 1 hour
- **Distance calculation** - Uses Haversine formula for accurate distance calculation
- **FCM integration** - Sends push notifications to all devices
- **Location tracking** - Updates user location every 15 minutes for accurate distance calculation

## Deployment Steps

### 1. Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### 2. Login to Firebase
```bash
firebase login
```

### 3. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. Verify Deployment
Check the Firebase Console > Functions to see your deployed functions.

## How It Works

### Aurora Sighting Notifications
1. User posts an aurora sighting
2. Cloud Function `onAuroraSightingCreated` automatically triggers
3. Function queries all users with `notificationSettings.alertNearby = true`
4. Calculates distance between sighting and each user's last known location
5. Sends push notification to users within 50km radius

### Location Updates
- Flutter app updates user location every 15 minutes
- Location is stored in `users/{userId}/lastKnownLocation`
- Used for accurate distance calculations

### High Activity Detection
- Function `checkHighActivity` can be called periodically
- Detects when 5+ sightings occur in 1 hour
- Sends notifications to users with `notificationSettings.highActivityAlert = true`

## Testing

### Test Aurora Sighting Notifications
1. Deploy the functions
2. Post an aurora sighting on one device
3. Users on other devices within 50km should receive push notifications

### Test High Activity
1. Call the `checkHighActivity` function via HTTP
2. If 5+ sightings in last hour, notifications will be sent

## Configuration

### Notification Radius
Change the `radiusKm` variable in `onAuroraSightingCreated` function:
```javascript
const radiusKm = 50; // Change this value
```

### High Activity Threshold
Change the threshold in `checkHighActivity` function:
```javascript
if (recentSightings.length >= 5) { // Change this number
```

### Location Update Frequency
Change the timer in `NotificationService.startLocationUpdates()`:
```dart
Timer.periodic(const Duration(minutes: 15), (timer) { // Change this duration
```

## Troubleshooting

### Functions Not Deploying
- Check Firebase CLI is logged in
- Verify you have the correct project selected
- Check for syntax errors in index.js

### Notifications Not Sending
- Verify FCM tokens are being saved to Firestore
- Check function logs in Firebase Console
- Ensure notification settings are enabled for users

### Location Issues
- Check location permissions in the app
- Verify `lastKnownLocation` is being updated in Firestore
- Check Geolocator permissions

## Security Rules

Make sure your Firestore rules allow:
- Users to read/write their own notification settings
- Cloud Functions to read user data and FCM tokens
- Users to update their last known location

## Cost Considerations

- Cloud Functions: Pay per invocation
- FCM: Free tier includes 1M messages/month
- Firestore: Pay per read/write operation

Monitor usage in Firebase Console to avoid unexpected costs. 