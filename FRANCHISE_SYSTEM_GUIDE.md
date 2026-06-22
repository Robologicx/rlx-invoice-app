# RLX Invoice → Multi-Branch Franchise Management System

## Implementation Guide

### Overview
This guide explains how the existing RLX Invoice application has been extended to support multi-branch franchise management while preserving all existing functionality.

---

## Architecture

### Role-Based Access Control

**Super Admin** (RoboLogicx Head Office)
- Access: `/super_admin` routes only
- Features: View all branches, manage franchises, track royalties, view aggregated reports
- Data Access: Can see all branch data across the franchise system
- User Model: `role: 'super_admin'`

**Branch Admin** (Franchise Owner / Branch Manager)
- Access: Regular RLX Invoice app (`/dashboard`, `/invoices`, etc.)
- Features: Create invoices, quotations, manage inventory, finance tracking (existing workflow)
- Data Access: Can only see own branch data
- User Model: `role: 'branch_admin'`, `branchId: '<branch_id>'`

---

## Data Model Changes

### New Collections

#### 1. `branches` (Top-level)
Stores information about each franchise location.

```dart
Branch {
  id: String,                    // Firestore doc ID
  name: String,                  // "Karachi", "Lahore", etc.
  code: String,                  // "KHI", "LHR"
  city: String,
  type: BranchType,             // 'main' or 'franchise'
  ownerName: String,
  phone: String,
  email: String,
  address: String,
  royaltyPercentage: double,    // 0, 5, 7, or custom
  status: BranchStatus,         // 'active', 'suspended', 'closed'
  mainBranchId: String?,        // For sub-franchises
  createdAt: DateTime,
  createdBy: String,
}
```

#### 2. `royalties` (Top-level)
Tracks monthly royalty calculations and payments.

```dart
Royalty {
  id: String,
  branchId: String,             // Reference to Branch
  branchName: String,
  month: int,                   // 1-12
  year: int,
  totalSales: double,           // Monthly sales from this branch
  royaltyPercentage: double,    // Branch royalty rate
  royaltyAmount: double,        // Calculated: totalSales * royaltyPercentage
  paidAmount: double,           // Amount already paid
  remainingBalance: double,     // Calculated: royaltyAmount - paidAmount
  status: RoyaltyStatus,        // 'pending', 'partiallyPaid', 'paid'
  paymentDate: DateTime?,
  notes: String?,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

#### 3. `branch_analytics` (Top-level)
Monthly performance metrics for each branch (auto-generated).

```dart
BranchAnalytics {
  id: String,                           // Format: "branchId_YYYY_MM"
  branchId: String,
  branchName: String,
  month: int,
  year: int,
  totalSales: double,
  invoiceCount: int,
  quotationCount: int,
  projectCount: int,
  profit: double,
  receivables: double,
  inventoryValue: double,
  updatedAt: DateTime,
}
```

### Enhanced Existing Collections

All existing collections now include optional `branchId` field:

```
users/{userId}/data/{invoiceId}
├─ type: 'invoice'
├─ amount: number
├─ branchId: String           ← NEW
├─ ...existing fields

users/{userId}/data/{quotationId}
├─ type: 'quotation'
├─ branchId: String           ← NEW
├─ ...existing fields

Similar for: projects, inventory, team_members, finance records
```

---

## Feature Structure

### Super Admin Feature Directory

```
lib/features/super_admin/
├── data/
│   ├── models/
│   │   ├── branch_model.dart
│   │   ├── royalty_model.dart
│   │   ├── branch_analytics_model.dart
│   │   └── models.dart
│   └── repositories/
│       ├── branch_repository.dart
│       ├── royalty_repository.dart
│       ├── analytics_repository.dart
│       └── repositories.dart
│
├── presentation/
│   ├── providers/
│   │   └── super_admin_providers.dart
│   ├── pages/
│   │   ├── dashboard_page.dart
│   │   ├── branch_management_page.dart
│   │   ├── branch_detail_page.dart
│   │   ├── royalty_page.dart
│   │   ├── reports_page.dart
│   │   └── pages.dart
│   ├── widgets/
│   │   ├── dashboard_stats.dart
│   │   ├── branch_summary_card.dart
│   │   ├── royalty_table.dart
│   │   ├── sales_chart.dart
│   │   └── widgets.dart
│   └── super_admin_shell.dart
```

---

## Integration Steps

### Step 1: Update User Model

Modify the user document structure to include role and branchId:

```dart
// Before
users/{uid} {
  email: "user@example.com",
  name: "John Doe",
  ...
}

// After
users/{uid} {
  email: "user@example.com",
  name: "John Doe",
  role: "branch_admin",           // ← NEW
  branchId: "karachi_branch",     // ← NEW (null for super_admin)
  ...existing fields
}
```

### Step 2: Update Firestore Rules

Replace existing `firestore.rules` with the multi-branch rules (see `firestore.rules.multi_branch`).

This enforces:
- Super Admin can access all collections and branches
- Branch Admin can only access their own branch data
- Prevents cross-branch data access

### Step 3: Update Authentication Service

Add role/branch checking in `lib/core/services/firebase_auth_service.dart`:

```dart
Future<String?> getUserRole() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  return doc.data()?['role'] as String?;
}

Future<String?> getUserBranchId() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  
  return doc.data()?['branchId'] as String?;
}
```

### Step 4: Add Routing

Update app router to add Super Admin routes:

```dart
// In app_router.dart
const superAdminRoute = '/super_admin';

routes: [
  GoRoute(
    path: superAdminRoute,
    name: 'super_admin',
    builder: (context, state) => const SuperAdminShell(),
    routes: [
      GoRoute(
        path: 'dashboard',
        name: 'dashboard',
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
  // ... existing routes for RLX Invoice
]
```

### Step 5: Update Main App Navigation

Add role-based navigation in `lib/app/app.dart`:

```dart
home: FutureBuilder<String?>(
  future: ref.read(firebaseAuthServiceProvider).getUserRole(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final role = snapshot.data;
    
    if (role == 'super_admin') {
      return const SuperAdminShell();
    } else if (role == 'branch_admin') {
      return const MainApp(); // Existing RLX Invoice app
    } else {
      return const LoginScreen();
    }
  },
)
```

### Step 6: Create Branch Management Forms

Create forms for creating/editing branches:

```dart
// lib/features/super_admin/presentation/pages/create_branch_page.dart
class CreateBranchPage extends ConsumerWidget {
  const CreateBranchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Form with fields: name, code, city, ownerName, email, phone, 
    // address, type, royaltyPercentage, status
    // On submit, call: ref.read(branchRepositoryProvider).createBranch(branch)
  }
}
```

---

## Daily Operations

### For Super Admin

1. **View Dashboard**: See all branches, total sales, royalties due/collected
2. **Manage Branches**: Create franchises, suspend/reactivate branches, update royalty rates
3. **Track Royalties**: View monthly royalty calculations, record payments
4. **Generate Reports**: Monthly franchise reports, PDF/Excel exports
5. **Monitor Performance**: Top-performing branches, sales trends, inventory value

### For Branch Admin

No changes to existing workflow. They continue using RLX Invoice exactly as before:
- Create invoices/quotations
- Manage inventory
- Track finance
- Generate reports (branch-specific only)

**Behind the scenes**: System automatically tags all branch records with `branchId`, allowing Super Admin aggregation.

---

## Royalty Calculation

### Monthly Royalty Process

1. **Collection**: System collects all invoices for branch in month
2. **Calculation**: 
   ```
   Monthly Sales = Sum of all invoice amounts (branch)
   Royalty Rate = Branch.royaltyPercentage
   Royalty Due = Monthly Sales × Royalty Rate / 100
   ```
3. **Recording**: New `Royalty` document created in `royalties` collection
4. **Payment Tracking**: Status updates as payments are recorded

### Example

```
Branch: Karachi
Month: June 2026
Royalty Rate: 7%
Total Sales: PKR 2,000,000
Royalty Due: PKR 140,000

Status: Pending → Partially Paid (PKR 50,000 paid) → Paid (PKR 140,000 paid)
```

---

## Data Aggregation

### Dashboard Aggregation

Super Admin dashboard shows consolidated data:

```dart
final totalSales = await analyticsRepo.getTotalMonthlySales(month, year);
final topBranches = await analyticsRepo.getTopBranches(month, year, limit: 5);
final totalRoyaltiesDue = await royaltyRepo.getTotalRoyaltiesDue();
```

This is done via:
1. **Firestore Queries**: Filtering `branch_analytics` and `royalties` collections
2. **Dart-side Aggregation**: Summing results for total calculations
3. **Real-time Updates**: Using StreamProviders for live dashboard updates

---

## Security

### Firestore Rules Enforcement

- **Super Admin Access**: Can read/write all collections and branches
- **Branch Admin Access**: Can only read/write own branch data
- **Data Isolation**: Queries automatically filtered by branchId via security rules

### Best Practices

1. Always check user role before showing Super Admin UI
2. Never expose branch data across branch boundaries
3. Log all administrative changes (create/update/delete branches)
4. Archive deleted branches (soft delete) instead of permanent deletion

---

## Migration Path (Existing Data)

### Option 1: Default Main Branch
```dart
// Assign all existing users to "Main" branch with 0% royalty
for (var userId in existingUsers) {
  await usersCollection.doc(userId).update({
    'branchId': 'main_branch',
    'role': 'branch_admin',
  });
}
```

### Option 2: Data Migration Helper
```dart
// lib/features/super_admin/services/data_migration_service.dart
class DataMigrationService {
  // Adds branchId to all existing invoices, quotations, etc.
  Future<void> migrateBranchData(String branchId) async { ... }
}
```

---

## Future Enhancements

1. **Multi-level Franchises**: Sub-franchises that split royalties with parent
2. **Dynamic Royalty Rates**: Different rates based on branch performance/tier
3. **Automated Royalty Reminders**: Email/SMS notifications for pending payments
4. **Advanced Analytics**: Predictive analytics, branch benchmarking
5. **Expenses Tracking**: Track franchise operating costs
6. **Disbursement Scheduling**: Auto-calculate and schedule royalty payments

---

## Testing Checklist

- [ ] Create test user account with super_admin role
- [ ] Create test user account with branch_admin role for Branch A
- [ ] Create test Branch A in database
- [ ] Create test invoices for Branch A
- [ ] Verify Super Admin can see all branches and invoices
- [ ] Verify Branch A admin can see only Branch A invoices
- [ ] Test royalty calculation: Create invoice for PKR 1,000,000, verify 7% = PKR 70,000
- [ ] Test royalty payment recording
- [ ] Test branch suspension/reactivation
- [ ] Test branch deletion (soft delete)
- [ ] Verify Firestore rules block cross-branch access
- [ ] Generate and export monthly report

---

## Support & Troubleshooting

### Super Admin Dashboard Shows No Data
- Verify user `role: 'super_admin'` in Firestore
- Check that branches exist in `branches` collection
- Verify Firestore rules allow Super Admin read access

### Branch Admin Can't See Data
- Verify user has `role: 'branch_admin'` and `branchId` set
- Verify branch exists in `branches` collection
- Check that invoices/quotations have matching `branchId`

### Royalty Calculations Incorrect
- Verify monthly analytics are updated after new invoices
- Check royalty percentage in branch document
- Ensure invoices have correct `branchId` field

---

## File Changes Summary

### New Files Created
- `lib/features/super_admin/` (entire feature)
- `firestore.rules.multi_branch`

### Files Modified
- `lib/app/app.dart` (add role-based navigation)
- `lib/core/services/firebase_auth_service.dart` (add role/branchId getters)
- `lib/app/router/app_router.dart` (add Super Admin routes)
- `firestore.rules` (deploy new multi-branch rules)
- `pubspec.yaml` (no new dependencies required)

### No Breaking Changes
- Existing RLX Invoice workflow unchanged
- Branch Admins continue using app as before
- All existing features preserved
