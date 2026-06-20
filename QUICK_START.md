# Quick Start: Cloud Setup (5 Minutes)

## ⚡ Get Your App Cloud-Ready in 5 Minutes

### Step 1: Create Firebase Project (2 min)
1. Open https://console.firebase.google.com
2. Click **"Create a new project"**
3. Name it `auto-invoicing-4176f`
4. Accept defaults, click **"Create"**
5. Wait for project to load

### Step 2: Register Web App (1 min)
1. Click the web icon `</>` in Firebase Console
2. Nickname: `RLX Invoice Web`
3. Click **"Register app"**
4. **COPY the config** (keep this tab open)

### Step 3: Update Code (1 min)
Open `lib/firebase_options.dart` and paste your config:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: '1:YOUR_PROJECT_NUMBER:web:YOUR_WEB_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'auto-invoicing-4176f',
  authDomain: 'auto-invoicing-4176f.firebaseapp.com',
  storageBucket: 'auto-invoicing-4176f.firebasestorage.app',
  measurementId: 'YOUR_MEASUREMENT_ID',
);
```

### Step 4: Enable Firestore & Auth (1 min)

**Enable Firestore:**
1. Click **"Firestore Database"**
2. Click **"Create Database"**
3. Start in **test mode**
4. Select nearest location
5. Click **"Create"**

**Enable Authentication:**
1. Click **"Authentication"**
2. Click **"Get Started"**
3. Click **"Email/Password"**
4. Click **toggle to enable**
5. Click **"Save"**

### Step 5: Run It! (0.5 min)
```bash
cd e:\robologicx invosing
flutter pub get
flutter run -d chrome
```

## 🎉 Done!

Your app now has:
✅ User login/signup  
✅ Cloud storage (Firestore)  
✅ Multi-device sync  
✅ Secure data isolation  

## Test It
1. Create account: test@example.com / password123
2. Create an invoice
3. **Refresh page** → Data persists ✅
4. Open in **new browser tab** → See same data ✅

## 📚 Full Docs
- **Setup details**: See `FIREBASE_SETUP.md`
- **Architecture**: See `CLOUD_MIGRATION_SUMMARY.md`
- **Troubleshooting**: See both docs above

## ⚠️ Common Issues

### "Field 'email' is required"
→ Copy `projectId` correctly from Firebase Console

### "Permission denied"
→ Wait 30 seconds after enabling Firestore

### Blank login screen
→ Check browser console (F12) for errors

## 🔒 Security Update

Add to `FIREBASE_SETUP.md` → Firestore Rules section:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      match /data/{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

Click **"Publish"** after pasting.

---

**Need help?** Check `FIREBASE_SETUP.md` for detailed instructions.

