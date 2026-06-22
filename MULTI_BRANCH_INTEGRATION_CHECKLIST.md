# Multi-Branch Franchise System - Integration Checklist

## Complete Implementation Overview

All core infrastructure for the multi-branch franchise system has been created. This checklist guides you through final integration steps.

---

## ✅ Completed Components

### Data Models
- [x] `Branch` model with type (main/franchise), royalty rate, status
- [x] `Royalty` model with payment tracking
- [x] `BranchAnalytics` model for monthly metrics
- [x] Enums: `BranchType`, `BranchStatus`, `RoyaltyStatus`

### Repositories
- [x] `BranchRepository` - full CRUD and queries
- [x] `RoyaltyRepository` - payment tracking and aggregations
- [x] `AnalyticsRepository` - performance metrics and trends

### Business Logic Services
- [x] `RoyaltyCalculationService` - monthly calculations, summaries
- [x] `BranchAnalyticsService` - data aggregation, comparisons

### Presentation Layer
- [x] `SuperAdminShell` - main navigation container
- [x] `SuperAdminDashboard` - KPI overview
- [x] `BranchManagementPage` - create/edit/delete branches
- [x] `BranchDetailPage` - tabbed view (overview, reports, royalties)
- [x] `RoyaltyManagementPage` - payment tracking
- [x] `ReportsPage` - monthly reports & export templates

### Widgets
- [x] `DashboardStats` - 6 key metrics cards
- [x] `BranchSummaryCard` - 2x3 grid of branch metrics
- [x] `RoyaltyTable` - DataTable for payment tracking
- [x] `SalesChart` - placeholder for charting library

### State Management
- [x] Riverpod providers for all repositories
- [x] Stream providers for real-time updates
- [x] Future providers for data aggregations

### Security
- [x] Firestore rules for role-based access control
- [x] Super Admin can read all branches
- [x] Branch Admin sees only own branch data

---

## 🔧 Integration Steps (In Order)

### Step 1: Update User Model ⚠️ CRITICAL

**File**: `lib/core/models/user_model.dart` (or wherever users are defined)

Add these fields to the user document:

```dart
{
  ...existing fields,
  
  // ADD THESE:
  'role': 'super_admin',  // or 'branch_admin'
  'branchId': 'karachi_branch',  // null for super_admin
}
```

**Action**: Modify user data class to include `role` and `branchId` fields.

---

### Step 2: Update Firebase Auth Service

**File**: `lib/core/services/firebase_auth_service.dart`

Add these methods:

```dart
/// Get the user's role (super_admin or branch_admin)
Future<String?> getUserRole() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  return doc.data()?['role'] as String?;
}

/// Get the user's assigned branch
Future<String?> getUserBranchId() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  return doc.data()?['branchId'] as String?;
}

/// Check if user is super admin
Future<bool> isSuperAdmin() async {
  final role = await getUserRole();
  return role == 'super_admin';
}
```

---

### Step 3: Deploy Firestore Security Rules

**File**: Copy rules from `firestore.rules.multi_branch`

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Navigate to: Firestore → Rules
3. Copy contents from `firestore.rules.multi_branch`
4. Click "Publish"
5. Verify rules deployed successfully

**⚠️ Important**: Old rules should be replaced entirely with the new multi-branch rules.

---

### Step 4: Update App Router

**File**: `lib/app/router/app_router.dart`

Add Super Admin routes:

```dart
import 'package:robologicx_workshop_app/features/super_admin/presentation/super_admin_shell.dart';
import 'package:robologicx_workshop_app/features/super_admin/presentation/pages/pages.dart';

// Add to GoRouter configuration:
GoRoute(
  path: '/super_admin',
  name: 'super_admin',
  builder: (context, state) => const SuperAdminShell(),
  routes: [
    GoRoute(
      path: 'dashboard',
      name: 'super_admin_dashboard',
      builder: (context, state) => const SuperAdminDashboard(),
    ),
    GoRoute(
      path: 'branches',
      name: 'branch_management',
      builder: (context, state) => const BranchManagementPage(),
    ),
    GoRoute(
      path: 'branch/:branchId',
      name: 'branch_detail',
      builder: (context, state) => BranchDetailPage(
        branchId: state.pathParameters['branchId']!,
      ),
    ),
    GoRoute(
      path: 'create_branch',
      name: 'create_branch',
      builder: (context, state) => const CreateBranchPage(),
    ),
    GoRoute(
      path: 'edit_branch/:branchId',
      name: 'edit_branch',
      builder: (context, state) => EditBranchPage(
        branchId: state.pathParameters['branchId']!,
      ),
    ),
    GoRoute(
      path: 'royalties',
      name: 'royalty_management',
      builder: (context, state) => const RoyaltyManagementPage(),
    ),
    GoRoute(
      path: 'reports',
      name: 'reports',
      builder: (context, state) => const ReportsPage(),
    ),
  ],
),
```

---

### Step 5: Update Main App Navigation

**File**: `lib/app/app.dart` or your main app initialization

Modify to route based on user role:

```dart
return FutureBuilder<String?>(
  future: ref.read(firebaseAuthServiceProvider).getUserRole(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final role = snapshot.data;
    
    if (role == 'super_admin') {
      // Navigate to Super Admin Dashboard
      return const SuperAdminShell();
    } else if (role == 'branch_admin') {
      // Navigate to existing RLX Invoice app
      return const MainApp(); // Your existing dashboard
    } else {
      // Navigate to login
      return const LoginScreen();
    }
  },
);
```

---

### Step 6: Create Branch Management Forms

**File**: Create `lib/features/super_admin/presentation/pages/create_branch_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

class CreateBranchPage extends ConsumerStatefulWidget {
  const CreateBranchPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateBranchPage> createState() => _CreateBranchPageState();
}

class _CreateBranchPageState extends ConsumerState<CreateBranchPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController nameController;
  late TextEditingController codeController;
  late TextEditingController cityController;
  late TextEditingController ownerNameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController addressController;
  late TextEditingController royaltyController;
  
  BranchType selectedType = BranchType.franchise;
  BranchStatus selectedStatus = BranchStatus.active;
  
  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    codeController = TextEditingController();
    cityController = TextEditingController();
    ownerNameController = TextEditingController();
    phoneController = TextEditingController();
    emailController = TextEditingController();
    addressController = TextEditingController();
    royaltyController = TextEditingController();
  }
  
  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    cityController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    royaltyController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Branch')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Branch Name'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Branch Code'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ownerNameController,
              decoration: const InputDecoration(labelText: 'Owner Name'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Required' : null,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BranchType>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Branch Type'),
              items: BranchType.values
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedType = value!);
              },
            ),
            const SizedBox(height: 16),
            if (selectedType == BranchType.franchise)
              TextFormField(
                controller: royaltyController,
                decoration: const InputDecoration(
                  labelText: 'Royalty Percentage',
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) return 'Invalid number';
                  return null;
                },
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<BranchStatus>(
              value: selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: BranchStatus.values
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedStatus = value!);
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveBranch,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Create Branch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final branch = Branch(
        id: '',
        name: nameController.text,
        code: codeController.text,
        city: cityController.text,
        type: selectedType,
        ownerName: ownerNameController.text,
        phone: phoneController.text,
        email: emailController.text,
        address: addressController.text,
        royaltyPercentage: selectedType == BranchType.franchise
            ? double.parse(royaltyController.text)
            : 0.0,
        status: selectedStatus,
        createdAt: DateTime.now(),
        createdBy: currentUser.uid,
      );
      
      final branchRepo = ref.read(branchRepositoryProvider);
      await branchRepo.createBranch(branch);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
```

---

### Step 7: Create Edit Branch Page

**File**: Create `lib/features/super_admin/presentation/pages/edit_branch_page.dart`

(Similar to CreateBranchPage, but loads existing data and calls updateBranch)

---

### Step 8: Update Existing Invoice Creation

**File**: `lib/features/invoices/presentation/create_invoice_screen.dart` (or similar)

When creating invoice, automatically tag with branchId:

```dart
// Before saving:
invoiceData['branchId'] = await ref.read(firebaseAuthServiceProvider).getUserBranchId();

// Then save as usual
```

Repeat for: quotations, projects, inventory, finance records.

---

### Step 9: Set Up Scheduled Tasks (Cloud Functions)

Create Google Cloud Function to run monthly:

**File**: Create `functions/index.js` (in your Firebase project):

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Run at 00:00 UTC on 1st of each month
exports.monthlyRoyaltyCalculation = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const now = new Date();
    const previousMonth = now.getMonth();
    const year = now.getFullYear();
    
    // Call your Dart function or make REST call
    console.log(`Calculating royalties for ${previousMonth}/${year}`);
    
    // This is where you'd trigger the calculation
    return true;
  });

// Run at 01:00 UTC on 1st of each month
exports.monthlyAnalyticsGeneration = functions.pubsub
  .schedule('0 1 1 * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const now = new Date();
    const previousMonth = now.getMonth();
    const year = now.getFullYear();
    
    console.log(`Generating analytics for ${previousMonth}/${year}`);
    
    return true;
  });
```

---

### Step 10: Add Missing Pages

Create these placeholder pages that reference existing widgets:

- [ ] `EditBranchPage` - form to edit branch details
- [ ] `RecordPaymentPage` - UI for recording royalty payments
- [ ] `BranchInvoicesTab` - read-only invoices for branch
- [ ] `BranchQuotationsTab` - read-only quotations for branch
- [ ] `BranchProjectsTab` - read-only projects for branch

---

## 🧪 Testing Checklist

### Prerequisites
- [ ] Test user created with `role: 'super_admin'`
- [ ] Test user created with `role: 'branch_admin'` and `branchId: 'test_branch'`
- [ ] Test branch created in Firestore

### Super Admin Tests
- [ ] Can navigate to `/super_admin`
- [ ] Dashboard loads and shows all statistics
- [ ] Can see all branches in Branch Management
- [ ] Can create new branch
- [ ] Can edit existing branch
- [ ] Can view branch details with all tabs
- [ ] Can see all royalties across all branches
- [ ] Can record royalty payment
- [ ] Can export reports to PDF/Excel

### Branch Admin Tests
- [ ] Cannot access `/super_admin` routes
- [ ] Can see only their own branch invoices/quotations
- [ ] New invoices automatically tagged with branchId
- [ ] Reports show only branch-specific data

### Data Isolation Tests
- [ ] Branch A admin cannot see Branch B invoices (via Firestore rules)
- [ ] Branch A admin cannot modify Branch B records
- [ ] Super Admin can see all branch records

### Royalty Calculation Tests
- [ ] Create invoice for PKR 1,000,000 in Branch A (7% rate)
- [ ] Monthly analytics generated: totalSales = 1,000,000
- [ ] Royalty calculated: 1,000,000 × 0.07 = PKR 70,000
- [ ] Royalty status = pending
- [ ] Record payment of PKR 50,000
- [ ] Royalty status = partiallyPaid
- [ ] Record payment of PKR 20,000
- [ ] Royalty status = paid

### Security Tests
- [ ] Logged-out users cannot access any data
- [ ] Branch admin cannot modify their own role
- [ ] Branch admin cannot change their branchId
- [ ] Firestore rules prevent unauthorized reads/writes

---

## 📊 File Structure Summary

```
lib/features/super_admin/
├── data/
│   ├── models/ (3 files)
│   │   ├── branch_model.dart
│   │   ├── royalty_model.dart
│   │   ├── branch_analytics_model.dart
│   │   └── models.dart (barrel)
│   ├── repositories/ (4 files)
│   │   ├── branch_repository.dart
│   │   ├── royalty_repository.dart
│   │   ├── analytics_repository.dart
│   │   └── repositories.dart (barrel)
│   └── services/ (2 files)
│       ├── royalty_calculation_service.dart
│       └── branch_analytics_service.dart
│
└── presentation/
    ├── providers/
    │   └── super_admin_providers.dart
    ├── pages/ (6 files)
    │   ├── dashboard_page.dart
    │   ├── branch_management_page.dart
    │   ├── branch_detail_page.dart
    │   ├── royalty_page.dart
    │   ├── reports_page.dart
    │   └── pages.dart (barrel)
    ├── widgets/ (5 files)
    │   ├── dashboard_stats.dart
    │   ├── branch_summary_card.dart
    │   ├── royalty_table.dart
    │   ├── sales_chart.dart
    │   └── widgets.dart (barrel)
    └── super_admin_shell.dart

Root directory:
├── firestore.rules.multi_branch (new security rules)
├── FRANCHISE_SYSTEM_GUIDE.md (complete documentation)
└── MULTI_BRANCH_INTEGRATION_CHECKLIST.md (this file)
```

---

## ⚠️ Critical Reminders

1. **Firestore Rules**: Must be deployed before system goes live
2. **User Roles**: Set up proper role assignments in Firebase Console
3. **Data Migration**: Existing invoices need `branchId` field added
4. **Branch Assignment**: Each user must have a `branchId` (except super_admin)
5. **Testing**: Thoroughly test cross-branch data isolation before production

---

## 🚀 Next Steps After Integration

1. Create admin panel in Firebase Console to assign roles
2. Generate initial data: Main branch, 2-3 test franchises
3. Create test invoices for each branch
4. Run royalty calculation and verify amounts
5. Test all user permissions
6. Deploy to production
7. Onboard franchise owners with login credentials

---

## 📞 Support Resources

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [Riverpod Documentation](https://riverpod.dev)
- [Flutter GoRouter Documentation](https://pub.dev/packages/go_router)
- [RoboLogicx Team Contact]: Ask in project chat

---

**Status**: 🟢 Ready for Integration

**Last Updated**: 2026-06-20

**Created By**: RLX Development Team
