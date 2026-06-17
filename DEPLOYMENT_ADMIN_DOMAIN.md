# Deployment to www.admin.robologicx.com

## ✅ Configuration Complete

Your Flutter app has been configured for deployment to **www.admin.robologicx.com**. The web build is ready in `build/web/`.

### What Was Done

1. ✅ **Updated Domain Reference** - Changed website from `www.robologicx.org` to `www.admin.robologicx.com` in app defaults
2. ✅ **Firebase Configuration** - Verified Firebase setup in `.firebaserc` and `firebase.json`
3. ✅ **Web Build** - Created optimized release build in `build/web/`

---

## 📋 Next Steps for Deployment

### Step 1: Install Firebase CLI (if not already installed)

```powershell
npm install -g firebase-tools
```

### Step 2: Login to Firebase

```powershell
firebase login
```

This will open a browser window. Sign in with your Google account that manages the Firebase project.

### Step 3: Deploy to Firebase Hosting

Deploy to the "admin" target:

```powershell
cd "e:\robologicx invosing"
firebase deploy --only hosting:admin
```

This will:
- Deploy the `build/web/` content to Firebase Hosting
- Serve it at **https://admin-robologicx-com.web.app**
- Connect to your custom domain **www.admin.robologicx.com** (if domain is configured)

### Step 4: Configure Custom Domain (if needed)

If your domain isn't already connected:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **rlx-invoice**
3. Go to **Hosting** → **Domains**
4. Click **Add custom domain**
5. Enter: `www.admin.robologicx.com`
6. Follow DNS setup instructions

---

## 🔐 Firebase Project Details

- **Project ID**: `rlx-invoice`
- **Hosting Target**: `admin` (maps to `admin-robologicx-com`)
- **Redirect Target**: `www` (redirects to admin)

---

## 📱 Mobile Apps (Optional)

For iOS and Android, the app automatically uses:
- **Firebase Project**: `auto-invoicing-4176f`
- **Auth Domain**: `auto-invoicing-4176f.firebaseapp.com`

No additional configuration needed for mobile unless you're changing Firebase projects.

---

## 🗂️ File Structure

```
project/
├── firebase.json           # Hosting targets configured ✅
├── .firebaserc            # Firebase project mapping ✅
├── lib/
│   ├── firebase_options.dart  # Firebase credentials ✅
│   └── core/data/demo_data.dart # Domain updated ✅
└── build/web/             # Ready for deployment ✅
```

---

## ✨ Commands Reference

```powershell
# View deployment status
firebase hosting:channel:list

# Deploy with message
firebase deploy --only hosting:admin -m "Version 1.0 deployment"

# View logs
firebase functions:log

# Test locally before deployment
flutter run -d chrome
```

---

## 🎯 Deployment Checklist

- [ ] Firebase CLI installed
- [ ] Logged in to Firebase (`firebase login`)
- [ ] Verified project: `firebase projects:list`
- [ ] Custom domain configured in Firebase Console
- [ ] Run: `firebase deploy --only hosting:admin`
- [ ] Visit https://www.admin.robologicx.com to verify

---

## 📞 Support

If deployment fails, check:

1. **Authentication**: `firebase login` and verify you're logged in
2. **Project**: Confirm `firebase projects:list` shows **rlx-invoice** as active
3. **Build**: Ensure `build/web/` directory exists and contains `index.html`
4. **DNS**: If using custom domain, verify DNS records are configured
5. **Firestore**: Rules and database must be accessible with your Firebase credentials

---

## 🚀 After Deployment

Once live, users will access the app at:
- **Web**: https://www.admin.robologicx.com
- **Business Details**: Updated to show `www.admin.robologicx.com`

All other functionality remains unchanged. The app uses your Firestore database which you'll access via Firebase Console.

