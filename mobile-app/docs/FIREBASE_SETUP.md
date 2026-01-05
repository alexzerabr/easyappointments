# Firebase Setup Guide

This guide explains how to configure Firebase for push notifications in the Easy!Appointments mobile app.

## Prerequisites

- A Firebase account (https://firebase.google.com)
- Flutter SDK installed
- Android Studio and/or Xcode

## Step 1: Create Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com)
2. Click "Add project"
3. Enter project name: "EasyAppointments" (or your preferred name)
4. Enable/disable Google Analytics as needed
5. Click "Create project"

## Step 2: Configure Android

### Add Android App

1. In Firebase Console, click "Add app" and select Android
2. Enter package name: `com.easyappointments.mobile`
3. Enter app nickname: "Easy!Appointments Android"
4. Download `google-services.json`
5. Place the file in `android/app/google-services.json`

### Update Android Configuration

Add to `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

Add to `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

### Create Notification Channel (Android 8+)

Create `android/app/src/main/res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="default_notification_channel_id">high_importance_channel</string>
</resources>
```

Update `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="@string/default_notification_channel_id"/>
```

## Step 3: Configure iOS

### Add iOS App

1. In Firebase Console, click "Add app" and select iOS
2. Enter bundle ID: `com.easyappointments.mobile`
3. Enter app nickname: "Easy!Appointments iOS"
4. Download `GoogleService-Info.plist`
5. Place the file in `ios/Runner/GoogleService-Info.plist`

### Update iOS Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Add `GoogleService-Info.plist` to the Runner target
3. Enable Push Notifications capability
4. Enable Background Modes > Remote notifications

Update `ios/Runner/AppDelegate.swift`:
```swift
import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## Step 4: Server-Side Configuration

### Obtain Server Key

1. In Firebase Console, go to Project Settings > Cloud Messaging
2. Under "Cloud Messaging API (Legacy)", enable it if needed
3. Copy the "Server key"
4. Add to your backend `.env` file:
   ```
   FIREBASE_SERVER_KEY=your_server_key_here
   ```

### Configure Backend Endpoints

The mobile app sends FCM tokens to the backend for push notification delivery.

Endpoint: `POST /api/v1/devices/register`
```json
{
  "fcm_token": "device_fcm_token",
  "platform": "android|ios"
}
```

## Step 5: Testing

### Test on Android Emulator

```bash
flutter run -d emulator-5554
```

### Test on iOS Simulator

Note: Push notifications don't work on iOS Simulator. Use a real device.

```bash
flutter run -d <device_id>
```

### Send Test Notification

Using Firebase Console:
1. Go to Engage > Messaging
2. Click "New campaign" > "Notifications"
3. Enter test message
4. Select target app
5. Send test message

## Troubleshooting

### Android: No notifications received
- Check if `google-services.json` is in the correct location
- Verify the package name matches
- Check if notification channel is created
- Look for FCM errors in logcat

### iOS: No notifications received
- Push notifications require a real device
- Check if APNs certificate is configured in Firebase
- Verify `GoogleService-Info.plist` is added to Xcode project
- Check entitlements for push notifications

### Token not generated
- Check internet connection
- Verify Firebase initialization
- Check for errors in app logs

## Additional Resources

- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
- [firebase_messaging package](https://pub.dev/packages/firebase_messaging)
- [flutter_local_notifications package](https://pub.dev/packages/flutter_local_notifications)
