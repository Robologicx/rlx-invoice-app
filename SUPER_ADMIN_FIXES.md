# Super Admin Feature - Quick Fix Guide

This document lists the remaining compilation errors and how to fix them.

## Errors to Fix

### 1. Print Statement (branch_analytics_service.dart)
**Line 127**: Remove print statement from production code

```dart
// REMOVE:
print('Error calculating analytics for branch $branchId: $e');
```

### 2. Router Import (branch_management_page.dart)
**Line 4**: Fix import path

```dart
// CHANGE FROM:
import '../../../app/router/app_router.dart';

// CHANGE TO:
import 'package:robologicx_workshop_app/app/router/app_router.dart';
```

### 3. GoRouter Usage (branch_management_page.dart)
**Lines 22, 40, 107, 116**: Use GoRouter instead of context.pushNamed

```dart
// CHANGE FROM:
context.pushNamed('create-branch');

// CHANGE TO:
context.push('/super_admin/create_branch');
// Or use GoRouter.of(context).pushNamed() if available
```

### 4. Type Conversion (reports_page.dart)
**Line 193**: Cast properly

```dart
// CHANGE FROM:
selectedMonth = DateTime(
  DateTime.now().year,
  DateTime.now().month - i,  // This creates negative months

// CHANGE TO:
final month = DateTime.now().month - i;
final year = DateTime.now().year;
final adjustedYear = month <= 0 ? year - 1 : year;
final adjustedMonth = month <= 0 ? 12 + month : month;
selectedMonth = DateTime(adjustedYear, adjustedMonth);
```

### 5. Unused Import (royalty_page.dart)
**Line 4**: Remove

```dart
// REMOVE:
import '../../data/models/models.dart';
```

### 6. Deprecated Method (royalty_table.dart)
**Line 48**: Update deprecated call

```dart
// CHANGE FROM:
color: _getStatusColor(r.status).withOpacity(0.2),

// CHANGE TO:
color: _getStatusColor(r.status).withValues(alpha: 0.2),
```

### 7. Missing Create/Edit Branch Pages

Create these two files:

**File**: `lib/features/super_admin/presentation/pages/create_branch_page.dart`
- See FRANCHISE_SYSTEM_GUIDE.md Step 6 for template

**File**: `lib/features/super_admin/presentation/pages/edit_branch_page.dart`
- Similar to create_branch_page.dart but loads and updates existing branch

---

## After Fixes

Run again:
```bash
flutter analyze lib/features/super_admin/
```

Should show 0 errors.

## Files Modified Summary
- ✅ branch_analytics_service.dart - Remove print
- ⏳ branch_management_page.dart - Fix imports and router usage
- ⏳ reports_page.dart - Fix date logic
- ⏳ royalty_page.dart - Remove unused import
- ⏳ royalty_table.dart - Update deprecated method
- ⏳ Create create_branch_page.dart
- ⏳ Create edit_branch_page.dart
