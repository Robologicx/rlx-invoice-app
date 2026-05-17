# Firestore Database Structure & Schema

This document describes how data is organized in Firestore for the RLX Invoice app.

## Overview

```
Firestore Database (rlx-invoice)
├── users/
│   └── {userId}/
│       ├── settings
│       ├── catalog
│       ├── inventory
│       ├── expenses
│       ├── teamMembers
│       └── data/
│           ├── {invoiceId1}
│           ├── {invoiceId2}
│           └── ...
└── public/
    └── {publicDataId}
```

---

## Collections & Documents

### 1. `/users/{userId}`
**Root user document**

```json
{
  "uid": "firebase_user_id",
  "email": "user@example.com",
  "displayName": "John Doe",
  "createdAt": 1715970000000,
  "lastLogin": 1715970000000
}
```

#### Subcollection: `/users/{userId}/settings`
**User settings (stored as single document)**

```json
{
  "geminiApiKey": "sk-...",
  "invoiceLogoBytes": "base64_encoded_image_bytes",
  "businessDetails": {
    "address": "123 Main St, City, State",
    "phone": "+1-555-0123",
    "email": "business@example.com",
    "website": "https://example.com"
  },
  "policySections": {
    "terms_conditions": "Terms and conditions text...",
    "payment_terms": "Net 30",
    "warranty": "1 year warranty"
  },
  "updatedAt": 1715970000000
}
```

#### Subcollection: `/users/{userId}/catalog`
**Service catalog/packages**

```json
{
  "profiles": {
    "electrical": {
      "name": "Electrical Services",
      "packages": {
        "installation": {
          "id": "electrical_install",
          "name": "Basic Installation",
          "description": "Standard electrical installation",
          "basePrice": 500,
          "defaultQuantity": 1,
          "quantityLabel": "units",
          "quantityDescription": "Number of installations",
          "rateRules": [
            {
              "minQuantity": 1,
              "maxQuantity": 5,
              "pricePerUnit": 500
            },
            {
              "minQuantity": 6,
              "maxQuantity": null,
              "pricePerUnit": 450
            }
          ]
        }
      }
    }
  },
  "updatedAt": 1715970000000
}
```

#### Subcollection: `/users/{userId}/inventory`
**Inventory items (array)**

```json
{
  "inventory": [
    {
      "id": "item_001",
      "name": "Circuit Breaker 20A",
      "sku": "CB-20A",
      "quantity": 50,
      "unit": "pieces",
      "unitPrice": 12.50,
      "category": "electrical",
      "lastUpdated": 1715970000000
    },
    {
      "id": "item_002",
      "name": "Copper Wire 10mm",
      "sku": "CW-10",
      "quantity": 100,
      "unit": "meters",
      "unitPrice": 2.50,
      "category": "electrical",
      "lastUpdated": 1715970000000
    }
  ]
}
```

#### Subcollection: `/users/{userId}/expenses`
**Expense tracking**

```json
{
  "expenses": [
    {
      "id": "exp_001",
      "type": "variable",
      "date": 1715970000000,
      "category": "materials",
      "description": "Electrical materials",
      "amount": 150.00,
      "notes": "Purchased from supplier X"
    },
    {
      "id": "exp_fixed_001",
      "type": "fixed",
      "amount": 5000.00,
      "category": "rent",
      "description": "Monthly office rent",
      "startDate": 1715970000000
    }
  ]
}
```

#### Subcollection: `/users/{userId}/teamMembers`
**Team members**

```json
{
  "teamMembers": [
    {
      "id": "tm_001",
      "name": "Alice Smith",
      "email": "alice@example.com",
      "role": "Technician",
      "phone": "+1-555-0456",
      "skills": ["electrical", "installation"],
      "active": true,
      "joinedDate": 1715970000000
    }
  ]
}
```

#### Subcollection: `/users/{userId}/data/{invoiceId}`
**Individual invoices/quotations**

```json
{
  "id": "INV-2024-001",
  "type": "invoice",
  "status": "sent",
  "clientName": "ABC Corporation",
  "clientEmail": "abc@example.com",
  "clientPhone": "+1-555-0789",
  "clientAddress": "456 Business Ave",
  "quoteDate": 1715970000000,
  "dueDate": 1716230400000,
  "invoiceNumber": "INV-2024-001",
  "referenceNumber": "REF-2024-001",
  "category": "electrical",
  "profile": "standard",
  "quotationLines": [
    {
      "id": "line_001",
      "itemName": "Installation Service",
      "quantity": 5,
      "quantityLabel": "units",
      "quantityDescription": "5 units at standard rate",
      "unitPrice": 500,
      "tax": 0.15,
      "total": 2875,
      "description": "Professional installation work"
    }
  ],
  "placeholderValues": {
    "company_name": "RLX Services",
    "company_address": "123 Main St",
    "quantity_label": "units",
    "quantity_description": "units of work"
  },
  "totalAmount": 2875,
  "taxAmount": 431.25,
  "discountAmount": 0,
  "finalAmount": 3306.25,
  "paymentStatus": "pending",
  "notes": "Thank you for your business!",
  "terms": "Net 30 days",
  "createdAt": 1715970000000,
  "updatedAt": 1715970000000,
  "migratedFrom": "hive"
}
```

### 2. `/public/{documentId}` (Optional)
**Public shared data (future use)**

```json
{
  "id": "public_template_001",
  "type": "template",
  "title": "Service Package Template",
  "description": "Reusable service package",
  "content": {...},
  "createdBy": "userId",
  "createdAt": 1715970000000,
  "shared": true
}
```

---

## Firestore Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User private data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      // All nested collections under user
      match /{document=**} {
        allow read, write: if request.auth.uid == userId;
      }
    }
    
    // Public data
    match /public/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

---

## Data Types Reference

| Field | Type | Example | Notes |
|---|---|---|---|
| userId | string | `"abc123xyz"` | Firebase Auth UID |
| timestamps | number | `1715970000000` | Milliseconds since epoch |
| prices | number | `500.25` | Stored as decimal |
| quantities | number | `5` | Integer or decimal |
| booleans | boolean | `true` / `false` | Boolean value |
| arrays | array | `["item1", "item2"]` | For lists |
| maps | map | `{"key": "value"}` | For nested objects |
| bytes | string | `"base64..."` | For binary data |

---

## Indexing

### Recommended Indexes

For optimal query performance:

```
Collection: /users/{userId}/data
Ascending: category
Ascending: profile
Descending: createdAt
```

Firestore will suggest these automatically when you first query.

---

## Backup Strategy

### Regular Backups
1. **Daily**: Automatic Firestore backups (via GCP)
2. **Weekly**: Export to Cloud Storage
3. **Monthly**: Download as JSON

### Export from Firestore
```bash
# Requires Firebase CLI
firebase firestore:export gs://your-bucket-name
```

---

## Migration Path

### From Hive to Firestore

The app automatically migrates:
- ✅ Settings
- ✅ Service catalog
- ✅ Invoices
- ✅ Inventory
- ✅ Expenses
- ✅ Team members

Each item gets a `migratedFrom: "hive"` flag.

---

## Performance Considerations

### Best Practices
1. **Keep documents small** - Break large data into subcollections
2. **Use proper indexing** - Index frequently queried fields
3. **Avoid N+1 queries** - Batch related data together
4. **Limit array sizes** - Keep array fields under 100 items
5. **Archive old data** - Move old invoices to archive collection

### Query Limits
- Max document size: 1 MB
- Max collection size: Unlimited
- Max concurrent connections: 100 per client

---

## Cost Calculation

### Sample Usage
- Users: 10
- Invoices per user per month: 20
- Monthly operations:
  - Reads: 10 users × 20 invoices × 3 reads = 600
  - Writes: 10 users × 20 invoices × 2 writes = 400
  - **Total: ~1,000 operations/month**

### Pricing (Google Cloud)
- First 50,000 reads/month: FREE
- Additional reads: $0.06 per 100K
- Writes: $0.18 per 100K
- Deletes: $0.02 per 100K

**Cost estimate**: ~$0.01-0.10/month for typical usage

---

## Common Queries

### Get all user's invoices
```
db.collection("users")
  .document(userId)
  .collection("data")
  .whereField("type", isEqualTo: "invoice")
  .orderBy("createdAt", descending: true)
  .getDocuments()
```

### Get user's settings
```
db.collection("users")
  .document(userId)
  .getDocument()
```

### Filter by date range
```
db.collection("users")
  .document(userId)
  .collection("data")
  .whereField("createdAt", isGreaterThanOrEqualTo: startDate)
  .whereField("createdAt", isLessThanOrEqualTo: endDate)
  .getDocuments()
```

---

## Schema Versioning

### Current Version: 1.0
- Firestore database structure
- Document schemas
- Collection organization

### Future Changes
Any breaking changes will include:
1. Version increment
2. Migration helper script
3. Backward compatibility layer

---

## Support

For questions about data structure:
1. Check this document
2. Review Firestore Rules section
3. See `COMPLETE_FIREBASE_SETUP.md`

---

**Last Updated**: May 17, 2026  
**Status**: Production Ready  
**Supported Platforms**: Web, Android
