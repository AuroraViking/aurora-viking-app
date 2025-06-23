# Notification System Debugging Guide

## Why Notifications Might Not Work

### 1. **Cloud Functions Not Deployed**
- Check if functions are deployed: `firebase functions:list`
- Deploy functions: `firebase deploy --only functions`

### 2. **FCM Tokens Not Saved**
- Check Firestore: `users/{userId}/fcmToken` should exist
- Verify token is being saved in `NotificationService.initialize()`

### 3. **Notification Settings Disabled**
- Check Firestore: `users/{userId}/notificationSettings/alertNearby` should be `true`
- Default is `true`, but user might have disabled it

### 4. **Location Issues**
- Check Firestore: `users/{userId}/lastKnownLocation` should exist
- Verify location permissions in app
- Check if location updates are running every 15 minutes

### 5. **Distance Calculation**
- Notifications only sent within 50km radius
- Check function logs for distance calculations

## Debugging Steps

### Step 1: Check Function Deployment
```bash
cd functions
firebase deploy --only functions
```

### Step 2: Test Notifications Manually
Call the test function:
```bash
curl -X GET "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/testNotifications"
```

### Step 3: Check Function Logs
```bash
firebase functions:log
```

### Step 4: Verify Firestore Data
Check these fields in Firestore:
- `users/{userId}/fcmToken` - Should contain FCM token
- `users/{userId}/notificationSettings/alertNearby` - Should be `true`
- `users/{userId}/lastKnownLocation` - Should contain lat/lng

### Step 5: Test Aurora Sighting
1. Post an aurora sighting
2. Check function logs for `onAuroraSightingCreated`
3. Look for detailed logging about users and distances

## Common Issues and Solutions

### Issue: "No users with nearby alerts enabled"
**Solution**: Check notification settings in Firestore

### Issue: "User has no FCM token"
**Solution**: 
- Verify app has notification permissions
- Check `NotificationService.initialize()` is called
- Ensure FCM token is being saved

### Issue: "User too far away"
**Solution**: 
- Check user's `lastKnownLocation` in Firestore
- Verify distance calculation (should be ≤50km)
- Consider increasing radius in Cloud Function

### Issue: "No notifications to send"
**Solution**: 
- Check if users have `alertNearby: true`
- Verify FCM tokens exist
- Check if users are within radius

## Testing the System

### 1. Manual Test
```bash
# Call test function
curl -X GET "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/testNotifications"
```

### 2. Aurora Sighting Test
1. Post aurora sighting on Device A
2. Check function logs for detailed output
3. Device B should receive notification if:
   - Has FCM token
   - Has `alertNearby: true`
   - Is within 50km
   - Has location data

### 3. Space Weather Test
```bash
# Call space weather check
curl -X GET "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/checkHighActivity"
```

## Function Logs to Look For

### Successful Notification
```
New aurora sighting created: [sightingId]
Found 3 users with nearby alerts enabled
Processing user [userId], FCM token: present
User [userId] location: [lat], [lng]
Distance from user [userId] to sighting: 25.34km
Sending notification to user [userId] (25km away)
Sent 2/3 notifications successfully
```

### Failed Notification
```
User [userId] has no FCM token, skipping
User [userId] too far away (75.23km > 50km)
No users with nearby alerts enabled
```

## Configuration

### Change Notification Radius
In `functions/index.js`:
```javascript
const radiusKm = 50; // Change this value
```

### Change Location Update Frequency
In `lib/services/notification_service.dart`:
```dart
Timer.periodic(const Duration(minutes: 15), (timer) { // Change this
```

### Change High Activity Threshold
In `functions/index.js`:
```javascript
if (totalSightings >= 5) { // Change this number
```

## Space Weather Integration

### Current Implementation
- Placeholder values for BzH and Kp
- Checks every 15 minutes
- Notifies users with `spaceWeatherAlert: true`

### To Add Real Data
Replace `getCurrentSpaceWeather()` with real API calls:
```javascript
// Fetch from NOAA/SWPC
const response = await fetch('https://services.swpc.noaa.gov/json/planetary_k_index_1m.json');
const data = await response.json();
return {
  bzH: data.bz_gsm,
  kpIndex: data.kp_index,
  timestamp: new Date()
};
```

## Monitoring

### Firebase Console
- Functions > Logs - Check for errors
- Firestore > Data - Verify user data
- Analytics > Events - Track notification delivery

### Key Metrics
- Function invocation count
- Notification delivery rate
- User engagement with notifications
- Distance distribution of notifications 