/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require('firebase-functions/v2/https');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const logger = require('firebase-functions/logger');
const fetch = require('node-fetch');

// Initialize Firebase Admin
initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// Calculate distance between two points using Haversine formula
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distance = R * c; // Distance in kilometers
  return distance;
}

// Check if location is dark enough for aurora visibility
function isDarkEnough(latitude, longitude) {
  const now = new Date();
  const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
  const localTime = new Date(utc + (longitude * 60000 / 15)); // Approximate timezone

  const hour = localTime.getHours();

  // Consider dark between 8 PM and 6 AM (20:00 - 06:00)
  return hour >= 20 || hour <= 6;
}

// Get aurora visibility based on latitude and Kp index
function getAuroraVisibility(latitude, kpIndex) {
  const absLatitude = Math.abs(latitude);

  // Aurora oval visibility based on Kp index
  // Higher Kp = aurora visible at lower latitudes
  if (kpIndex >= 7) {
    // Kp 7+: Aurora visible down to ~40° latitude
    return absLatitude >= 40;
  } else if (kpIndex >= 5) {
    // Kp 5-6: Aurora visible down to ~50° latitude
    return absLatitude >= 50;
  } else if (kpIndex >= 3) {
    // Kp 3-4: Aurora visible down to ~60° latitude
    return absLatitude >= 60;
  } else {
    // Kp 0-2: Aurora visible only at high latitudes
    return absLatitude >= 65;
  }
}

// Send push notification to a specific user
async function sendPushNotification(fcmToken, title, body, data = {}) {
  try {
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: data,
      android: {
        notification: {
          channelId: 'aurora_viking_channel',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.send(message);
    logger.info('Successfully sent message:', response);
    return true;
  } catch (error) {
    logger.error('Error sending message:', error);
    return false;
  }
}

// Cloud Function: Triggered when a new aurora sighting is created
exports.onAuroraSightingCreated = onDocumentCreated('aurora_sightings/{sightingId}', async (event) => {
  try {
    const sightingData = event.data.data();
    const sightingId = event.params.sightingId;

    logger.info('New aurora sighting created:', sightingId);
    logger.info('Sighting data:', sightingData);

    // Extract sighting information
    const {
      userId: posterUserId,
      userName,
      location,
      locationName,
      intensity,
    } = sightingData;

    if (!location || !location.latitude || !location.longitude) {
      logger.warn('Sighting missing location data:', sightingId);
      return;
    }

    const sightingLat = location.latitude;
    const sightingLon = location.longitude;

    logger.info(`Sighting location: ${sightingLat}, ${sightingLon} by user ${posterUserId}`);

    // Get all users who have nearby alerts enabled
    const usersSnapshot = await db.collection('users')
      .where('notificationSettings.alertNearby', '==', true)
      .get();

    logger.info(`Found ${usersSnapshot.size} users with nearby alerts enabled`);

    if (usersSnapshot.empty) {
      logger.info('No users with nearby alerts enabled');
      return;
    }

    const notificationPromises = [];
    const radiusKm = 50; // 50km radius for notifications

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      const fcmToken = userData.fcmToken;

      logger.info(`Processing user ${userId}, FCM token: ${fcmToken ? 'present' : 'missing'}`);

      // Skip if it's the same user who posted the sighting
      if (userId === posterUserId) {
        logger.info(`Skipping poster user ${userId}`);
        continue;
      }

      // Skip if user has no FCM token
      if (!fcmToken) {
        logger.info(`User ${userId} has no FCM token, skipping`);
        continue;
      }

      // Check if user has a last known location
      if (userData.lastKnownLocation) {
        const userLat = userData.lastKnownLocation.latitude;
        const userLon = userData.lastKnownLocation.longitude;

        logger.info(`User ${userId} location: ${userLat}, ${userLon}`);

        // Calculate distance
        const distance = calculateDistance(userLat, userLon, sightingLat, sightingLon);

        logger.info(`Distance from user ${userId} to sighting: ${distance.toFixed(2)}km`);

        // Only send notification if within radius
        if (distance <= radiusKm) {
          const title = 'Aurora Spotted Nearby! 🌌';
          const body = `${userName} spotted aurora (${intensity}⭐) near ${locationName}`;

          const notificationData = {
            type: 'aurora_sighting',
            sightingId: sightingId,
            distance: Math.round(distance).toString(),
            intensity: intensity.toString(),
          };

          notificationPromises.push(
            sendPushNotification(fcmToken, title, body, notificationData)
          );

          logger.info(`Sending notification to user ${userId} (${Math.round(distance)}km away)`);
        } else {
          logger.info(`User ${userId} too far away (${distance.toFixed(2)}km > ${radiusKm}km)`);
        }
      } else {
        logger.info(`User ${userId} has no location data, sending notification anyway`);
        // If user has no location, send notification anyway (they might be traveling)
        const title = 'Aurora Spotted Nearby! 🌌';
        const body = `${userName} spotted aurora (${intensity}⭐) near ${locationName}`;

        const notificationData = {
          type: 'aurora_sighting',
          sightingId: sightingId,
          intensity: intensity.toString(),
        };

        notificationPromises.push(
          sendPushNotification(fcmToken, title, body, notificationData)
        );

        logger.info(`Sending notification to user ${userId} (no location data)`);
      }
    }

    // Send all notifications
    if (notificationPromises.length > 0) {
      logger.info(`Attempting to send ${notificationPromises.length} notifications`);
      const results = await Promise.all(notificationPromises);
      const successCount = results.filter((result) => result).length;
      logger.info(`Sent ${successCount}/${notificationPromises.length} notifications successfully`);
    } else {
      logger.info('No notifications to send');
    }
  } catch (error) {
    logger.error('Error processing aurora sighting notification:', error);
  }
});

// Cloud Function: Check for high activity and send notifications
exports.checkHighActivity = onRequest(async (request, response) => {
  try {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    // Get sightings from the last hour
    const sightingsSnapshot = await db.collection('aurora_sightings')
      .where('timestamp', '>', oneHourAgo)
      .get();

    const recentSightings = sightingsSnapshot.docs.map((doc) => doc.data());

    // Enhanced high activity detection
    const highActivityResult = await detectHighActivity(recentSightings);

    if (highActivityResult.isHighActivity) {
      // Get users with high activity alerts enabled
      const usersSnapshot = await db.collection('users')
        .where('notificationSettings.highActivityAlert', '==', true)
        .get();

      const notificationPromises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (fcmToken) {
          const title = 'High Aurora Activity! 🌟';
          const body = highActivityResult.message;

          const notificationData = {
            type: 'high_activity',
            location: highActivityResult.location,
            count: highActivityResult.totalSightings.toString(),
            intensity: highActivityResult.avgIntensity.toString(),
            reason: highActivityResult.reason,
          };

          notificationPromises.push(
            sendPushNotification(fcmToken, title, body, notificationData)
          );
        }
      }

      if (notificationPromises.length > 0) {
        const results = await Promise.all(notificationPromises);
        const successCount = results.filter((result) => result).length;
        logger.info(`Sent ${successCount}/${notificationPromises.length} high activity notifications`);
      }
    }

    response.json({
      success: true,
      message: 'High activity check completed',
      result: highActivityResult,
    });
  } catch (error) {
    logger.error('Error checking high activity:', error);
    response.status(500).json({error: 'Internal server error'});
  }
});

// Enhanced high activity detection function
async function detectHighActivity(sightings) {
  if (sightings.length === 0) {
    return {isHighActivity: false};
  }

  // Calculate metrics
  const totalSightings = sightings.length;
  const avgIntensity = sightings.reduce((sum, s) => sum + (s.intensity || 1), 0) / totalSightings;
  const highIntensitySightings = sightings.filter((s) => (s.intensity || 1) >= 4).length;

  // Group by location
  const locationCounts = {};
  const locationIntensities = {};

  sightings.forEach((sighting) => {
    const locationName = sighting.locationName || 'Unknown Location';
    locationCounts[locationName] = (locationCounts[locationName] || 0) + 1;

    if (!locationIntensities[locationName]) {
      locationIntensities[locationName] = [];
    }
    locationIntensities[locationName].push(sighting.intensity || 1);
  });

  // Find most active location
  const mostActiveLocation = Object.entries(locationCounts)
    .reduce((a, b) => a[1] > b[1] ? a : b)[0];

  const mostActiveLocationIntensity = locationIntensities[mostActiveLocation] || [];
  const mostActiveAvgIntensity = mostActiveLocationIntensity.length > 0 ?
    mostActiveLocationIntensity.reduce((a, b) => a + b, 0) / mostActiveLocationIntensity.length :
    0;

  // Multiple detection criteria
  let isHighActivity = false;
  let reason = '';
  let message = '';

  // Criterion 1: High volume (5+ sightings in 1 hour)
  if (totalSightings >= 5) {
    isHighActivity = true;
    reason = 'high_volume';
    message = `${totalSightings} aurora sightings reported near ${mostActiveLocation} in the last hour!`;
  }

  // Criterion 2: High intensity activity (3+ high intensity sightings)
  if (highIntensitySightings >= 3) {
    isHighActivity = true;
    reason = 'high_intensity';
    message = `${highIntensitySightings} high-intensity aurora sightings (4-5⭐) reported in the last hour!`;
  }

  // Criterion 3: Exceptional activity (10+ sightings OR average intensity 4+)
  if (totalSightings >= 10 || avgIntensity >= 4) {
    isHighActivity = true;
    reason = 'exceptional_activity';
    message = `Exceptional aurora activity! ${totalSightings} sightings with average intensity ` +
      `${avgIntensity.toFixed(1)}⭐`;
  }

  // Criterion 4: Localized high activity (5+ sightings in same location with high intensity)
  if (locationCounts[mostActiveLocation] >= 5 && mostActiveAvgIntensity >= 3.5) {
    isHighActivity = true;
    reason = 'localized_high_activity';
    message = `Intense aurora activity at ${mostActiveLocation}! ` +
      `${locationCounts[mostActiveLocation]} sightings with ` +
      `${mostActiveAvgIntensity.toFixed(1)}⭐ average intensity`;
  }

  return {
    isHighActivity,
    reason,
    message: message || `${totalSightings} aurora sightings reported near ${mostActiveLocation} in the last hour`,
    totalSightings,
    avgIntensity: Math.round(avgIntensity * 10) / 10,
    highIntensitySightings,
    location: mostActiveLocation,
    locationSightings: locationCounts[mostActiveLocation],
    locationAvgIntensity: Math.round(mostActiveAvgIntensity * 10) / 10,
  };
}

// Cloud Function: Update user's last known location
exports.updateUserLocation = onRequest(async (request, response) => {
  try {
    const {userId, latitude, longitude} = request.body;

    if (!userId || latitude === undefined || longitude === undefined) {
      response.status(400).json({error: 'Missing required fields'});
      return;
    }

    await db.collection('users').doc(userId).update({
      lastKnownLocation: {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude)
      },
      lastUpdated: new Date(),
    });

    logger.info(`Updated location for user ${userId}`);
    response.json({success: true});
  } catch (error) {
    logger.error('Error updating user location:', error);
    response.status(500).json({error: 'Internal server error'});
  }
});

// Scheduled function: Automatically check for high activity every 30 minutes
exports.scheduledHighActivityCheck = onSchedule('every 30 minutes', async () => {
  try {
    logger.info('Running scheduled high activity check');

    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    // Get sightings from the last hour
    const sightingsSnapshot = await db.collection('aurora_sightings')
      .where('timestamp', '>', oneHourAgo)
      .get();

    const recentSightings = sightingsSnapshot.docs.map((doc) => doc.data());

    // Enhanced high activity detection
    const highActivityResult = await detectHighActivity(recentSightings);

    if (highActivityResult.isHighActivity) {
      logger.info(`High activity detected: ${highActivityResult.reason}`, highActivityResult);

      // Get users with high activity alerts enabled
      const usersSnapshot = await db.collection('users')
        .where('notificationSettings.highActivityAlert', '==', true)
        .get();

      const notificationPromises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (fcmToken) {
          const title = 'High Aurora Activity! 🌟';
          const body = highActivityResult.message;

          const notificationData = {
            type: 'high_activity',
            location: highActivityResult.location,
            count: highActivityResult.totalSightings.toString(),
            intensity: highActivityResult.avgIntensity.toString(),
            reason: highActivityResult.reason,
          };

          notificationPromises.push(
            sendPushNotification(fcmToken, title, body, notificationData)
          );
        }
      }

      if (notificationPromises.length > 0) {
        const results = await Promise.all(notificationPromises);
        const successCount = results.filter((result) => result).length;
        logger.info(`Scheduled check: Sent ${successCount}/${notificationPromises.length} high activity notifications`);
      }
    } else {
      logger.info('No high activity detected in scheduled check');
    }
  } catch (error) {
    logger.error('Error in scheduled high activity check:', error);
  }
});

// Scheduled function: Check space weather conditions every 15 minutes
exports.scheduledSpaceWeatherCheck = onSchedule('every 15 minutes', async () => {
  try {
    logger.info('Running scheduled space weather check');

    // Get current space weather data (production-ready)
    const spaceWeatherData = await getCurrentSpaceWeather();

    if (spaceWeatherData) {
      const {bzH, kpIndex} = spaceWeatherData;

      // Check if conditions are favorable for aurora
      if (Math.abs(bzH) >= 5 && kpIndex >= 3) {
        logger.info(`Favorable space weather detected: BzH=${bzH}, Kp=${kpIndex}`);

        // Get all users with space weather alerts enabled
        const usersSnapshot = await db.collection('users')
          .where('notificationSettings.spaceWeatherAlert', '==', true)
          .get();

        const notificationPromises = [];

        for (const userDoc of usersSnapshot.docs) {
          const userData = userDoc.data();
          const fcmToken = userData.fcmToken;
          const lastKnownLocation = userData.lastKnownLocation;

          if (fcmToken && lastKnownLocation) {
            const {latitude, longitude} = lastKnownLocation;

            // Check if user's location can see aurora
            if (getAuroraVisibility(latitude, kpIndex) && isDarkEnough(latitude, longitude)) {
              const title = 'Aurora Alert! 🌌';
              const body = `Favorable space weather! BzH: ${bzH}, Kp: ${kpIndex}. Look for aurora tonight!`;

              const notificationData = {
                type: 'space_weather',
                bzH: bzH.toString(),
                kpIndex: kpIndex.toString(),
                latitude: latitude.toString(),
                longitude: longitude.toString(),
              };

              notificationPromises.push(
                sendPushNotification(fcmToken, title, body, notificationData)
              );

              logger.info(
                `Sending space weather alert to user ${userDoc.id} at ${latitude}, ${longitude}`
              );
            }
          }
        }

        if (notificationPromises.length > 0) {
          const results = await Promise.all(notificationPromises);
          const successCount = results.filter((result) => result).length;
          logger.info(
            `Space weather: Sent ${successCount}/${notificationPromises.length} notifications`
          );
        }
      }
    }
  } catch (error) {
    logger.error('Error in scheduled space weather check:', error);
  }
});

// Function to get current space weather data (production-ready)
async function getCurrentSpaceWeather() {
  try {
    // Fetch Kp index from NOAA SWPC
    const kpResponse = await fetch('https://services.swpc.noaa.gov/json/planetary_k_index_1m.json');
    const kpData = await kpResponse.json();
    // Get the latest Kp value
    const lastKpObj = kpData[kpData.length - 1];
    const latestKp = lastKpObj && lastKpObj.kp_index ? lastKpObj.kp_index : 0;

    // Fetch BzH from NOAA SWPC (DSCOVR real-time solar wind)
    const bzResponse = await fetch('https://services.swpc.noaa.gov/products/solar-wind/mag-1-day.json');
    const bzData = await bzResponse.json();
    // The first row is headers, the last row is the latest data
    const latestBzRow = bzData[bzData.length - 1];
    // BzH is usually the 8th column (index 7)
    const latestBzH = parseFloat(latestBzRow[7]) || 0;

    return {
      bzH: latestBzH,
      kpIndex: latestKp,
    };
  } catch (error) {
    logger.error('Error fetching space weather data:', error);
    return null;
  }
}

// Test function
exports.helloWorld = onRequest((request, response) => {
  logger.info('Hello logs!', {structuredData: true});
  response.send('Hello from Firebase!');
});

// Test function: Manually trigger notifications for debugging
exports.testNotifications = onRequest(async (request, response) => {
  try {
    logger.info('Testing notifications manually');

    // Get all users with FCM tokens
    const usersSnapshot = await db.collection('users').get();

    const notificationPromises = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      const userId = userDoc.id;

      if (fcmToken) {
        logger.info(`Sending test notification to user ${userId}`);

        const title = 'Test Notification 🔔';
        const body = 'This is a test notification from Aurora Viking!';

        const notificationData = {
          type: 'test',
          userId: userId,
          timestamp: new Date().toISOString(),
        };

        notificationPromises.push(
          sendPushNotification(fcmToken, title, body, notificationData)
        );
      } else {
        logger.info(`User ${userId} has no FCM token`);
      }
    }

    if (notificationPromises.length > 0) {
      const results = await Promise.all(notificationPromises);
      const successCount = results.filter((result) => result).length;

      logger.info(`Test: Sent ${successCount}/${notificationPromises.length} notifications`);

      response.json({
        success: true,
        message: `Test notifications sent: ${successCount}/${notificationPromises.length} successful`,
        totalUsers: usersSnapshot.size,
        usersWithTokens: notificationPromises.length,
        successfulNotifications: successCount,
      });
    } else {
      response.json({
        success: false,
        message: 'No users with FCM tokens found',
        totalUsers: usersSnapshot.size,
      });
    }
  } catch (error) {
    logger.error('Error in test notifications:', error);
    response.status(500).json({error: 'Internal server error', details: error.message});
  }
});
