# Complete Firebase Setup with Firestore - Step by Step

## Prerequisites
- Google Account (free)
- 5-10 minutes of time

---

## STEP 1: Create Firebase Project

### Go to Firebase Console
1. Open: **https://console.firebase.google.com**
2. Click **"Create a project"**
3. Project name: `auto-invoicing-4176f`
4. Accept analytics (or disable if you prefer)
5. Click **"Create Project"**
6. Wait ~1 minute for project to initialize

---

## STEP 2: Register Web App

### In Firebase Console:
1. Click the **web icon** `</>`
2. App nickname: `RLX Invoice Web`
3. Click **"Register app"**
4. You'll see Firebase config like this:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  authDomain: "auto-invoicing-4176f.firebaseapp.com",
  projectId: "auto-invoicing-4176f",
  storageBucket: "auto-invoicing-4176f.firebasestorage.app",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abcdefg123456789"
};
```

5. **COPY this entire config** (you'll need it in Step 4)

---

## STEP 3: Enable Firestore Database

### In Firebase Console:
1. Click **"Firestore Database"** (in left menu under "Build")
2. Click **"Create Database"**
3. Location: Choose nearest to you (e.g., "us-central1")
4. Mode: Select **"Start in test mode"**
5. Click **"Create"**
6. Wait for database to initialize (~30 seconds)

### You'll see empty database dashboard

---

## STEP 4: Update Your Code

### Open: `lib/firebase_options.dart`

Replace the file contents with:

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  // Web Configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PASTE_YOUR_WEB_API_KEY_HERE',
    appId: '1:YOUR_PROJECT_NUMBER:web:YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_WEB_MESSAGING_SENDER_ID',
    projectId: 'auto-invoicing-4176f',
    authDomain: 'auto-invoicing-4176f.firebaseapp.com',
    storageBucket: 'auto-invoicing-4176f.firebasestorage.app',
    measurementId: 'G-XXXXXXXXXXX',
  );

  // Android Configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PASTE_YOUR_ANDROID_API_KEY_HERE',
    appId: '1:YOUR_PROJECT_NUMBER:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_ANDROID_MESSAGING_SENDER_ID',
    projectId: 'auto-invoicing-4176f',
    storageBucket: 'auto-invoicing-4176f.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (Platform.isWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
```

### Where to find values from Firebase Console:

From the config you copied in Step 2, map them like this:

| From Firebase Config | Goes to `firebase_options.dart` |
|---|---|
| `apiKey` | `apiKey: '...'` |
| `appId` | `appId: '1:PROJECT_NUMBER:web:WEB_APP_ID'` |
| `projectId` | `projectId: 'auto-invoicing-4176f'` |
| `authDomain` | `authDomain: '...'` |
| `storageBucket` | `storageBucket: '...'` |
| `messagingSenderId` | `messagingSenderId: '...'` |
| `measurementId` | `measurementId: 'G-...'` |

---

## STEP 5: Enable Authentication

### In Firebase Console:
1. Click **"Authentication"** (in left menu under "Build")
2. Click **"Get started"**
3. Click **"Email/Password"** provider
4. Toggle **Enable** switch to ON
5. Click **"Save"**

---

## STEP 6: Set Firestore Security Rules

### In Firebase Console:
1. Click **"Firestore Database"**
2. Click the **"Rules"** tab
3. Delete all existing text
4. Paste these rules:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User data - only accessible to that user
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      // Nested collections under user
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    
    // Public data (optional - for future shared features)
    match /public/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

5. Click **"Publish"**

### Rules Explanation:
- ✅ Each user can only read/write their own `/users/{userId}` folder
- ✅ All data under user folder is private to that user
- ✅ Optional public collection for future features

---

## STEP 7: Register Android App

### In Firebase Console:
1. Click **"Project Settings"** (gear icon, top right)
2. Click **"Your apps"** tab
3. Click the **Android icon** (if not already added)
4. Android package name: `com.robologicx.robologicx_workshop_app`
5. Click **"Register app"**
6. Download **`google-services.json`**
7. Place it here: **`android/app/google-services.json`**

---

## STEP 8: Update Android Build Config

### Edit: `android/build.gradle.kts`

Add Google Services plugin at the top:

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

### Edit: `android/app/build.gradle.kts`

At the very top, add:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // ADD THIS LINE
}
```

---

## STEP 9: Get Dependencies

### Run:
```bash
cd e:\robologicx invosing
flutter pub get
```

---

## STEP 10: Test It!

### Run on Web:
```bash
flutter run -d chrome
```

### Test Flow:
1. **Sign up**: Click "Sign Up"
   - Email: `test@example.com`
   - Password: `Test@123456`
   - Name: `Test User`
2. **Create Invoice**: Click "Invoices" → "New Invoice"
3. **Refresh Page**: Press F5
   - ✅ Invoice should still be there (saved to Firestore)
4. **Check Firestore**: 
   - Go to Firebase Console
   - Click "Firestore Database"
   - You should see collection: `users` → `test_user_id` → with your data

### Run on Android:
```bash
flutter run -d android  # if device connected
flutter run -d emulator # if using emulator
```

---

## STEP 11: Verify in Firestore Console

### Expected Data Structure:

```
Firestore Database
└── users/
    └── {userId}/
        ├── settings: {geminiApiKey: "...", ...}
        ├── catalog: {profiles: {...}}
        ├── inventory: [{item1}, {item2}, ...]
        ├── expenses: [{expense1}, ...]
        ├── teamMembers: [{member1}, ...]
        └── data/
            ├── {invoiceId1}: {type: "invoice", ...}
            ├── {invoiceId2}: {type: "invoice", ...}
            └── ...
```

---

## Troubleshooting

### ❌ "Permission Denied" Error
**Solution:**
1. Wait 30 seconds after publishing rules
2. Log out and back in
3. Check browser console (F12) for exact error

### ❌ Login Shows Blank Screen
**Solution:**
1. Open Chrome DevTools (F12)
2. Check Console tab for errors
3. Verify `firebase_options.dart` has correct values
4. Check Firebase Console → Authentication → see if user was created

### ❌ "Project ID is invalid"
**Solution:**
1. Copy `projectId` exactly from Firebase Console
2. Remove quotes if present
3. Example: `auto-invoicing-4176f` (not `"your-project-id"`)

### ❌ Data Not Showing in Firestore
**Solution:**
1. Check user is logged in (check top right username)
2. Navigate to invoice screen and create new invoice
3. Wait 2-3 seconds for sync
4. Refresh Firestore Console to see updates

### ❌ Android Build Fails
**Solution:**
1. Ensure `google-services.json` is in `android/app/`
2. Run `flutter clean` then `flutter pub get`
3. Check Android package name matches Firebase config

---

## Advanced: Firebase Emulator (Optional)

For local testing without internet:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Start emulator
firebase emulators:start

# In your app, use emulator (optional - for testing)
```

---

## Production Checklist

Before deploying:

- [ ] Update Firebase rules from "test mode" to production
- [ ] Set up backup in Firestore settings
- [ ] Enable billing (free tier is usually enough)
- [ ] Set up monitoring/alerts
- [ ] Configure CORS for your domain
- [ ] Enable authentication methods (Google, etc.)
- [ ] Test on real devices
- [ ] Set up error reporting

---

## Quick Reference

| What | Where |
|---|---|
| Create Project | https://console.firebase.google.com |
| View Database | Firebase Console → Firestore Database |
| View Rules | Firebase Console → Firestore → Rules |
| View Users | Firebase Console → Authentication |
| View API Keys | Firebase Console → Project Settings |

---

## What's Next?

After this setup works:
1. ✅ App has user login
2. ✅ All data saves to cloud
3. ✅ Multi-device sync works
4. ✅ Secure user isolation

Next features you could add:
- [ ] Google Sign-In
- [ ] Invoice sharing
- [ ] Team collaboration
- [ ] Offline support
- [ ] Push notifications
- [ ] Payment integration

---

## Support Links

- **Firebase Docs**: https://firebase.google.com/docs
- **Firestore Rules**: https://firebase.google.com/docs/firestore/security/start
- **Flutter Firebase**: https://firebase.flutter.dev/
- **Authentication**: https://firebase.google.com/docs/auth

---

**Status**: Ready to setup  
**Estimated Time**: 10 minutes  
**Cost**: FREE (forever on free tier)

