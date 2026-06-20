# RLX Invoice Cloud Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     RLX Invoice App - Cloud Based              │
└─────────────────────────────────────────────────────────────────┘

                        ┌──────────────────────┐
                        │   User's Devices     │
                        ├──────────────────────┤
                        │ • Chrome Browser     │
                        │ • Android Phone      │
                        │ • Android Tablet     │
                        │ • iOS (future)       │
                        └──────────┬───────────┘
                                   │
                        ┌──────────▼──────────┐
                        │  RLX Invoice App    │
                        ├────────────────────┤
                        │ • Login Screen      │
                        │ • Invoices UI       │
                        │ • Settings Panel    │
                        │ • Projects Screen   │
                        └──────────┬──────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
    ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐
    │ Firebase Auth   │  │ Firestore DB     │  │ Cloud Files  │
    ├─────────────────┤  ├──────────────────┤  ├──────────────┤
    │ • Sign Up       │  │ • Invoices       │  │ • Logos      │
    │ • Login         │  │ • Settings       │  │ • Uploads    │
    │ • Password      │  │ • Catalog        │  │ • Exports    │
    │ • Sessions      │  │ • Inventory      │  │              │
    │ • Reset Pass    │  │ • Expenses       │  │              │
    └─────────────────┘  │ • Team           │  └──────────────┘
                         └──────────────────┘

                    Google Firebase (Cloud)
```

---

## Data Flow Diagram

### Creating Invoice

```
User (Web/Android)
    │
    │ Clicks "New Invoice"
    ▼
┌──────────────────────┐
│ Invoices Screen      │
│ (Flutter Widget)     │
└──────────┬───────────┘
           │ Fills form
           ▼
┌──────────────────────┐
│ quotationController  │
│ (Business Logic)     │
└──────────┬───────────┘
           │ setCategory(), setProfile(), setPackage()
           ▼
┌──────────────────────┐
│ Riverpod Provider    │
│ State Management     │
└──────────┬───────────┘
           │ Triggers save
           ▼
┌──────────────────────┐
│ FirestoreService     │
│ saveInvoice()        │
└──────────┬───────────┘
           │ HTTP Request
           ▼
┌──────────────────────┐
│ Firebase Firestore   │
│ Cloud Database       │
│ /users/{id}/data/    │
│   {invoiceId}        │
└──────────────────────┘
           │
           │ Real-time
           │ Sync
           ▼
┌──────────────────────┐
│ All User Devices     │
│ Receive Update       │
│ Auto-refresh UI      │
└──────────────────────┘
```

---

## Authentication Flow

```
┌─────────────────────────────────────────┐
│        New User Registration            │
└─────────────────────────────────────────┘
                    │
      ┌─────────────▼─────────────┐
      │ Enter Email & Password    │
      │ Click "Sign Up"           │
      └──────────┬────────────────┘
                 │
      ┌──────────▼──────────┐
      │ Firebase Auth API   │
      │ createUserWith      │
      │ EmailAndPassword()  │
      └──────────┬──────────┘
                 │
         ┌───────┴────────┐
         │                │
      ✅ Success      ❌ Error
         │                │
         ▼                ▼
    ┌─────────┐  ┌──────────────────┐
    │ New     │  │ Show Error:      │
    │ Auth    │  │ • Email in use   │
    │ Token   │  │ • Weak password  │
    │ Created │  │ • Invalid email  │
    └────┬────┘  └──────────────────┘
         │
         ▼
    ┌─────────────────────────┐
    │ User Logged In          │
    │ Redirect to Dashboard   │
    └─────────────────────────┘
```

---

## Real-Time Sync

```
┌──────────────┐          ┌──────────────────┐          ┌──────────────┐
│ Device #1    │          │ Firebase         │          │ Device #2    │
│ (Chrome)     │          │ Firestore        │          │ (Android)    │
├──────────────┤          ├──────────────────┤          ├──────────────┤
│ Opens app    │          │                  │          │              │
│ Logs in      │          │                  │          │              │
│              │          │                  │          │              │
│ Creates      │ ────────▶│ Saves Invoice    │          │              │
│ Invoice      │  POST    │ INV-001          │          │              │
│              │          │                  │          │              │
│              │          │ Broadcasts       │◀─────────│ Listening    │
│              │          │ Update Event     │  Stream  │ for changes  │
│              │          │                  │          │              │
│ Invoice      │          │                  │          │ Invoice      │
│ appears in   │          │                  │          │ auto-appears │
│ list! ✅     │          │                  │          │ in list! ✅  │
└──────────────┘          └──────────────────┘          └──────────────┘

(No manual refresh needed - automatic real-time sync!)
```

---

## Data Structure

```
┌─────────────────────────────────────────────────────┐
│ Firestore Database: auto-invoicing-4176f                     │
└─────────────────────────────────────────────────────┘

Collection: /users
│
├─ Document: user123
│  ├─ Collection: data
│  │  ├─ Document: INV-2024-001
│  │  │  ├─ id: "INV-2024-001"
│  │  │  ├─ type: "invoice"
│  │  │  ├─ clientName: "ABC Corp"
│  │  │  ├─ totalAmount: 5000
│  │  │  ├─ status: "sent"
│  │  │  └─ quotationLines: [...]
│  │  │
│  │  └─ Document: INV-2024-002
│  │     └─ ...
│  │
│  ├─ Document: settings
│  │  ├─ geminiApiKey: "sk-..."
│  │  ├─ businessDetails:
│  │  │  ├─ address: "123 Main St"
│  │  │  ├─ phone: "+1-555-0123"
│  │  │  └─ email: "biz@example.com"
│  │  └─ policySections: {...}
│  │
│  ├─ Document: catalog
│  │  └─ profiles: {...}
│  │
│  ├─ Document: inventory
│  │  └─ [...list of items...]
│  │
│  └─ Document: expenses
│     └─ [...list of expenses...]
│
└─ Document: user456
   └─ (Same structure, different user)
```

---

## Security Model

```
┌─────────────────────────────────────────────────────┐
│           Firestore Security Rules                  │
└─────────────────────────────────────────────────────┘

Rule 1: User Data Access
┌─────────────────────────────────────────────────────┐
│ /users/{userId} - ONLY accessible to that user     │
│                                                     │
│ ✅ User123 can read/write /users/user123           │
│ ❌ User123 CANNOT read /users/user456              │
│ ❌ Anonymous users cannot read anything            │
└─────────────────────────────────────────────────────┘

Rule 2: Cascading Access
┌─────────────────────────────────────────────────────┐
│ /users/{userId}/{any nested path}                  │
│                                                     │
│ ✅ User123 can access:                             │
│   - /users/user123/data/invoices                   │
│   - /users/user123/settings                        │
│   - /users/user123/inventory/items                 │
│                                                     │
│ ❌ User123 CANNOT access these for other users     │
└─────────────────────────────────────────────────────┘

Rule 3: Public Data (Optional)
┌─────────────────────────────────────────────────────┐
│ /public/{document} - Readable by everyone          │
│                     Writable by authenticated users │
│                                                     │
│ (For future features like shared templates)        │
└─────────────────────────────────────────────────────┘
```

---

## Multi-Device Sync Example

```
Timeline: User has 3 devices logged in

T=0:00  ┌─ Device 1: Opens app, logged in
        ├─ Device 2: Opens app, logged in
        └─ Device 3: Opens app, logged in
                    (All listening to Firestore)

T=0:15  ┌─ Device 1: Creates Invoice #001
        │           ┌──────────────────────┐
        │           │ Firestore: Save      │
        │           │ INV-001 created      │
        │           └──────────────────────┘
        │
        ├─ Device 2: 🔔 Notification!
        │            Auto-refreshes list
        │            Shows Invoice #001 ✅
        │
        └─ Device 3: 🔔 Notification!
                     Auto-refreshes list
                     Shows Invoice #001 ✅

T=0:30  ┌─ Device 2: Edits Invoice #001
        │           ┌──────────────────────┐
        │           │ Firestore: Update    │
        │           │ INV-001 modified     │
        │           └──────────────────────┘
        │
        ├─ Device 1: 🔔 Updates!
        │            Shows latest version ✅
        │
        └─ Device 3: 🔔 Updates!
                     Shows latest version ✅

T=0:45  ┌─ Device 3: Offline (no internet)
        │            Still shows invoices
        │            Queued for sync
        │
        ├─ Device 1: Creates Invoice #002
        │            Shows in Device 1 ✅
        │            Shows in Device 2 ✅
        │            Shows in Device 3 ❌ (offline)
        │
        └─ Device 3: Internet back!
                     Auto-syncs
                     Shows Invoice #002 ✅

Result: All 3 devices always synchronized! 🎉
```

---

## Technology Stack

```
┌──────────────────────────────────────────────────────┐
│                    Frontend Layer                     │
├──────────────────────────────────────────────────────┤
│ Flutter / Dart                                       │
│ • Cross-platform (Web, Android, iOS)                │
│ • Reactive UI with Riverpod                         │
│ • Material Design                                   │
└────────────────────┬─────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────┐
│               State Management Layer                  │
├──────────────────────────────────────────────────────┤
│ Riverpod                                             │
│ • Providers for auth state                          │
│ • Streaming providers for real-time data            │
│ • Dependency injection                              │
└────────────────────┬─────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────┐
│                Service Layer                         │
├──────────────────────────────────────────────────────┤
│ • FirebaseAuthService                               │
│ • FirestoreService                                  │
│ • DataMigrationHelper                               │
└────────────────────┬─────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────┐
│              Firebase SDK (Google)                    │
├──────────────────────────────────────────────────────┤
│ • firebase_core: Core initialization                │
│ • firebase_auth: User authentication                │
│ • cloud_firestore: Real-time database               │
│ • firebase_storage: File uploads                    │
└────────────────────┬─────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────┐
│            Google Cloud Platform                     │
├──────────────────────────────────────────────────────┤
│ • Firebase Authentication                           │
│ • Firestore Database                                │
│ • Cloud Storage                                     │
│ • Auto-scaling & Load balancing                     │
│ • 99.99% SLA                                        │
└──────────────────────────────────────────────────────┘
```

---

## Deployment Architecture

```
┌────────────────────────────────────────────────────────┐
│                User Access Points                      │
├─────────────────────┬──────────────────┬───────────────┤
│ Web Browser         │ Android Device   │ iOS Device    │
│ (Chrome, Firefox)   │ (Phone, Tablet)  │ (Future)      │
└──────────┬──────────┴────────┬─────────┴────────┬──────┘
           │                   │                  │
           │                   │                  │
           └───────────────────┼──────────────────┘
                               │
                ┌──────────────▼─────────────────┐
                │   Internet (HTTPS/SSL)         │
                └──────────────┬─────────────────┘
                               │
              ┌────────────────▼─────────────────┐
              │    Google Cloud Infrastructure   │
              ├────────────────┬─────────────────┤
              │  Firebase Auth │ Firestore DB    │
              │  • Hashing     │ • Replication   │
              │  • Sessions    │ • Backups       │
              │  • 2FA         │ • Indexing      │
              │  • Limits      │ • Security      │
              └────────────────┴─────────────────┘
                               │
              ┌────────────────▼─────────────────┐
              │     Cloud Storage (Backups)      │
              │  • 30-day retention              │
              │  • Automatic daily backups       │
              │  • Multi-region replication      │
              └────────────────────────────────────┘
```

---

## Development to Production Pipeline

```
┌──────────────────────────────────────────────┐
│         Local Development                    │
│ • Write code on laptop                       │
│ • Test on Chrome/Android emulator            │
│ • Connected to Firebase test database        │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│         Firebase Console                     │
│ • Monitor database usage                     │
│ • View user activity                         │
│ • Check security rules                       │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│         Production Deployment                │
│ • Update Firestore rules                     │
│ • Enable authentication providers            │
│ • Set up monitoring/alerts                   │
│ • Enable automatic backups                   │
└──────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│         User Devices                         │
│ • Web: Share link                            │
│ • Android: Upload to Play Store              │
│ • iOS: Upload to App Store (future)          │
└──────────────────────────────────────────────┘
```

---

## Monitoring & Analytics

```
┌─────────────────────────────────────────────────┐
│            What You Can Monitor                 │
├─────────────────────────────────────────────────┤
│                                                 │
│ 📊 Firestore:                                  │
│   • Read/Write operations per day              │
│   • Storage usage                              │
│   • Real-time connections                      │
│   • Query performance                          │
│                                                 │
│ 👤 Authentication:                             │
│   • New user signups                           │
│   • Active users                               │
│   • Failed login attempts                      │
│   • Security alerts                            │
│                                                 │
│ 💰 Billing:                                    │
│   • Estimated monthly cost                     │
│   • Usage breakdown                            │
│   • Quota warnings                             │
│                                                 │
│ 🔒 Security:                                   │
│   • Rule violations                            │
│   • Suspicious activity                        │
│   • Data access logs                           │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Performance Metrics

```
┌────────────────────────────────────────────────┐
│         Expected Performance                   │
├────────────────────────────────────────────────┤
│                                                │
│ Login:           ~500ms (first time)           │
│ Create Invoice:  ~200ms (save to cloud)        │
│ List Invoices:   ~100ms (from cache)           │
│ Real-time Sync:  <100ms (push notification)    │
│ PDF Export:      ~1000ms (generate)            │
│                                                │
│ Network:         HTTPS encrypted               │
│ Latency:         <100ms from US               │
│ Uptime:          99.99% (Firebase SLA)        │
│                                                │
└────────────────────────────────────────────────┘
```

---

## Future Enhancements

```
┌────────────────────────────────────────────────┐
│        Possible Future Features                │
├────────────────────────────────────────────────┤
│                                                │
│ ✨ Phase 2:                                   │
│   • Invoice sharing (with links)              │
│   • Email delivery                            │
│   • Payment processing                        │
│   • Auto-reminders                            │
│                                                │
│ ✨ Phase 3:                                   │
│   • Team collaboration                        │
│   • Permission levels                         │
│   • Activity logging                          │
│   • Audit trails                              │
│                                                │
│ ✨ Phase 4:                                   │
│   • Mobile app (iOS native)                   │
│   • Offline mode                              │
│   • Sync queue                                │
│   • Cloud printing                            │
│                                                │
│ ✨ Phase 5:                                   │
│   • AI-powered insights                       │
│   • Forecasting                               │
│   • Optimization suggestions                  │
│   • API for integrations                      │
│                                                │
└────────────────────────────────────────────────┘
```

---

**Architecture Status**: ✅ Production Ready  
**Last Updated**: May 17, 2026  
**Platforms**: Web (Chrome), Android  
**Cloud Provider**: Google Firebase  

