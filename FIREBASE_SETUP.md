# Firebase Setup Guide for RLX Invoice App

This document explains how to set up Firebase Firestore and Authentication for the RLX Invoice app.

## Prerequisites

- A Google account
- Firebase project (create at https://console.firebase.google.com)
- Flutter SDK and dependencies installed

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a new project"
3. Enter your project name (e.g., "auto-invoicing-4176f")
4. Complete the setup wizard
5. Wait for the project to be created

## Step 2: Create a Web App

1. In the Firebase Console, click the gear icon and select "Project Settings"
2. Go to the "General" tab
3. Under "Your apps", click the web icon `</>`
4. Register your app with a nickname (e.g., "RLX Invoice Web")
5. Copy the Firebase configuration

## Step 3: Update firebase_options.dart

Open `lib/firebase_options.dart` and replace the placeholder values with your Firebase config:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',  // From Firebase Console
  appId: '1:YOUR_PROJECT_NUMBER:web:YOUR_WEB_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'your-firebase-project-id',
  authDomain: 'your-firebase-project-id.firebaseapp.com',
  storageBucket: 'your-firebase-project-id.appspot.com',
  measurementId: 'YOUR_MEASUREMENT_ID',
);
```

## Step 4: Enable Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create Database"
3. Select your location (closest to your users)
4. Choose "Start in test mode" (for development)
5. Wait for the database to be created

## Step 5: Set Up Security Rules

Replace the default security rules with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users can access their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      match /data/{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

1. In Firestore Database, go to "Rules" tab
2. Replace the content with the rules above
3. Click "Publish"

## Step 6: Enable Authentication

1. In Firebase Console, go to "Authentication"
2. Click "Get Started"
3. Click the "Email/Password" provider
4. Enable it and click "Save"
5. (Optional) Enable other providers like Google Sign-In

## Step 7: Update pubspec.yaml and Run

The pubspec.yaml already has Firebase dependencies, but verify:

```yaml
dependencies:
  firebase_core: ^3.1.0
  firebase_auth: ^5.1.0
  cloud_firestore: ^5.1.0
  firebase_storage: ^12.1.0
```

Then run:
```bash
flutter pub get
```

## Step 8: Run the App

```bash
flutter run -d chrome
```

The app will now:
1. Show the login screen
2. Allow users to sign up or log in
3. Store all data in Firestore under their user ID
4. Automatically sync data across devices

## Data Structure

All user data is stored under:
```
/users/{userId}/
  ├── settings: {...}
  ├── catalog: {...}
  ├── inventory: [...]
  └── data/
      ├── {invoiceId}: {...}
      ├── {invoiceId}: {...}
      └── ...
```

## Migration from Local Storage (Hive)

If you want to migrate existing local data to Firestore:

1. Export data from Hive to JSON
2. Create a migration script to upload to Firestore
3. Run migration after user logs in

This will be implemented in a future update.

## Troubleshooting

### "Could not determine your location"
- Update firebase_options.dart with correct credentials from Firebase Console

### "Permission denied" errors
- Check Firestore security rules are properly set
- Verify user is authenticated

### Slow sync
- Check internet connection
- Review Firestore indexes in console

### CORS errors
- Ensure the web app is registered in Firebase Console
- Update firebase_options.dart with correct values

## Next Steps

1. Test user registration and login
2. Create new invoices and verify they save to Firestore
3. Check Firestore Console to see created documents
4. Test on multiple devices/browsers (data should sync)
5. Set up Firestore backup strategy

## Support

For Firebase documentation, visit: https://firebase.flutter.dev/

