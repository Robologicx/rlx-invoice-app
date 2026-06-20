# Firebase Setup Verification Checklist

## Pre-Setup
- [ ] Google Account ready
- [ ] 10 minutes available
- [ ] You have editor open (`lib/firebase_options.dart`)

## During Setup

### Firebase Console
- [ ] Created Firebase project named `auto-invoicing-4176f`
- [ ] Registered Web app
- [ ] Created Firestore Database (test mode)
- [ ] Copied Web Firebase config
- [ ] Enabled Email/Password authentication
- [ ] Published Firestore security rules
- [ ] Registered Android app
- [ ] Downloaded `google-services.json`

### Code Updates
- [ ] Updated `lib/firebase_options.dart` with Web config values
- [ ] Placed `google-services.json` in `android/app/`
- [ ] Updated `android/build.gradle.kts` with Google Services plugin
- [ ] Updated `android/app/build.gradle.kts` with plugin ID
- [ ] Ran `flutter pub get`

## Testing

### Web Test
- [ ] Ran `flutter run -d chrome`
- [ ] Login screen appears
- [ ] Can sign up with email/password
- [ ] Can create invoice
- [ ] Refreshed page → invoice still exists
- [ ] Firestore Console shows `users/` collection with data

### Android Test
- [ ] Connected device/emulator
- [ ] Ran `flutter run -d android`
- [ ] App installs successfully
- [ ] Login screen appears
- [ ] Can sign up and create invoice

## Post-Setup

### Security
- [ ] Firestore rules are set (not test mode)
- [ ] Only authenticated users can create accounts
- [ ] Users can only see their own data

### Firestore Console
- [ ] Can see `/users/{userId}/` structure
- [ ] Can see `/users/{userId}/data/` with invoices
- [ ] Can see `/users/{userId}/settings` with app settings

### Cleanup
- [ ] Deleted example google-services.json (keep real one)
- [ ] Removed demo data from Firestore if created
- [ ] Noted down project ID for future reference

## Troubleshooting Done

### If Issues Occurred:
- [ ] Checked browser console for errors (F12)
- [ ] Verified all credentials copied correctly
- [ ] Waited 30 seconds after rule changes
- [ ] Tried clearing app data and relogging in
- [ ] Checked Firestore Rules tab was actually published

## Production Ready

- [ ] All tests pass on Web
- [ ] All tests pass on Android
- [ ] User data syncs to Firestore
- [ ] Multi-device sync works (logged in on 2 devices)
- [ ] Real-time updates working
- [ ] Rules prevent data leaks between users

---

## Common Values to Record

Save these for later reference:

```
Project ID: auto-invoicing-4176f
Firebase URL: https://auto-invoicing-4176f.firebaseapp.com
Storage Bucket: auto-invoicing-4176f.firebasestorage.app
Android Package: com.robologicx.robologicx_workshop_app
Web Domain: localhost:52437 (or your domain)
```

---

## Next Steps After Setup

1. **Migrate existing data** (optional)
   - See `CLOUD_MIGRATION_SUMMARY.md`

2. **Enable more auth methods**
   - Google Sign-In
   - Phone authentication

3. **Set up backups**
   - Export scheduled backups

4. **Monitor usage**
   - Set up billing alerts
   - Track API usage

---

**Status**: Use this as your setup confirmation  
**Mark items as completed**: ✅ (copy-paste to mark done)  
**Stuck?**: Check `COMPLETE_FIREBASE_SETUP.md` for detailed steps

