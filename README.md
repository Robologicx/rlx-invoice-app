# RLX Invoice

RLX Invoice is a local-first Flutter business application built for Robologicx. It combines quotation generation, invoice tracking, inventory control, finance reporting, payroll-style team expenses, backup/restore, and responsive dashboards in a single app for desktop, web, and mobile.

The project started as a workshop invoicing app and has grown into a lightweight ERP-style operational tool for service businesses such as solar, CCTV, electric fence, smart automation, networking, maintenance, and robotics projects.

## Overview

RLX Invoice is designed to help a team manage the full operating cycle of a services business:

- Create quotations from predefined service profiles and packages.
- Convert work into invoices and keep historical records.
- Track inventory items, stock changes, and low-stock thresholds.
- Record manual expenses and recurring fixed monthly expenses.
- Manage team members, salaries, and project commissions.
- Review business performance from live dashboard and finance reports.
- Export monthly finance reports as PDF.
- Back up all local data and restore it when needed.

## Main Features

### 1. Dashboard

The dashboard gives a quick overview of business health using live metrics derived from invoices, inventory, and expenses.

Typical metrics include:

- total sales
- total expenses
- current month profit or loss
- invoice activity
- inventory stock and low-stock visibility

The dashboard layout is responsive and adapts to smaller screens for mobile use.

### 2. Projects and Quotation Generation

The quotation system is based on service categories, templates, and service packages.

Supported service categories include:

- Electric Fence
- Solar System
- CCTV / IP Camera
- Smart Gate Automation
- Smart Home
- Robotics Projects
- Networking
- Maintenance Services

Each profile can contain:

- a business template
- one or more packages
- package products
- optional items
- system variants
- pricing rules and notes
- warranty and terms

Users can generate quotations either manually or from an AI-style prompt parser that helps interpret requested services and quantities.

### 3. Invoices

The invoice module handles generation and management of invoices from quotation data.

Capabilities include:

- preparing quotations and invoices from service packages
- storing quotation and invoice history locally
- retaining payment values and remaining balances
- reloading previous records back into the editor for updates or reuse

The invoicing flow is integrated with inventory so stock usage can be reflected in inventory movement when applicable.

### 4. Inventory Management

The inventory module provides a practical stock management workflow for products used in quotations and delivery.

Capabilities include:

- add inventory items
- edit inventory details
- delete inventory items
- adjust stock in or out
- define minimum stock thresholds
- view low-stock items
- track inventory movement history
- estimate current inventory value

Inventory is stored locally in dedicated Hive boxes and is included in the backup file.

### 5. Finance and Expense Management

The finance module is used to monitor operational performance and track outgoing costs.

Capabilities include:

- add manual expenses
- organize expenses by category
- keep expense notes and dates
- review current month sales, expenses, and profit
- browse monthly finance reports
- export selected month reports as PDF

The finance screen is responsive for smaller screens and supports month selection for reporting and export.

### 6. Fixed Monthly Expenses

The app supports recurring monthly expenses such as rent, utilities, subscriptions, or any repeated business cost.

Capabilities include:

- add fixed monthly expenses
- edit or delete recurring expense definitions
- enable or disable individual fixed expenses
- sync the current month to generate expense entries
- auto-add fixed monthly expenses once per month

This helps reduce repeated manual entry for operational costs.

### 7. Team Management

The team module replaces a traditional client-management section and is focused on internal operations.

Capabilities include:

- add team members
- store salary values
- store project commission values
- edit and remove team members
- post monthly salary and commission values into the expense system

This allows payroll-style costs to be reflected directly in finance reporting.

### 8. History

The history module gives access to previously created quotation and invoice records so work can be reviewed and reused without re-entering everything.

### 9. Settings and Application Administration

The settings area centralizes app-level controls and business preferences.

Capabilities include:

- theme mode selection
- backup export
- backup restore
- logo and invoice configuration support
- invoice policy section management
- Firestore collection structure display for reference
- branding/footer information

The default theme is light.

## Backup and Restore

RLX Invoice is local-first. Data is stored on-device using Hive and can be exported as a JSON backup.

### What is included in backup

The backup currently includes all major local data boxes:

- templates
- invoices
- products
- app settings
- inventory items
- inventory movements
- expenses
- fixed monthly expenses
- team members

### Backup behavior

- On mobile and desktop, the app always writes a backup copy into application storage.
- That backup remains available until the app is uninstalled or storage is cleared.
- Users can also export a JSON backup file to a chosen location.
- On web, the backup is downloaded through the browser.

### Restore behavior

- Users can select a JSON backup file.
- The file is decoded and each managed Hive box is restored.
- Existing data in those managed boxes is replaced with backup content.

## PDF Reporting

The finance module can generate and share a PDF report for the selected month.

The report includes monthly financial information such as:

- selected reporting month
- invoice summary
- expense summary
- monthly totals
- sales, expenses, and profit values

PDF generation uses the `pdf` and `printing` packages.

## Data Storage Model

The app uses Hive for local persistence.

Primary boxes include:

- `templates_box`
- `invoices_box`
- `products_box`
- `app_settings_box`
- `inventory_items_box`
- `inventory_movements_box`
- `expenses_box`
- `fixed_monthly_expenses_box`
- `team_members_box`

This architecture keeps the app functional without requiring a cloud backend for day-to-day use.

## App Navigation

The main application routes currently include:

- `/` - Dashboard
- `/projects` - Projects
- `/invoices` - Invoices
- `/inventory` - Inventory
- `/finance` - Finance
- `/team` - Team
- `/history` - History
- `/settings` - Settings

## Tech Stack

- Flutter
- Dart
- Riverpod for state management
- GoRouter for navigation
- Hive / Hive Flutter for local data persistence
- Shared Preferences for lightweight settings
- Intl for formatting
- PDF and Printing for report export
- File Picker and Path Provider for file access and backup storage
- Google Fonts for typography

## Project Structure

High-level project layout:

```text
lib/
	ai/
	app/
		router/
		theme/
	core/
		data/
		models/
	database/
	features/
		dashboard/
		finance/
		history/
		inventory/
		invoices/
		projects/
		settings/
		team/
	invoice_engine/
	shared/
```

### Important folders

- `lib/app/` contains routing, app bootstrapping, and theme configuration.
- `lib/core/` contains shared models and seed or support data.
- `lib/database/` contains Hive initialization and local storage box definitions.
- `lib/features/` contains user-facing modules by domain.
- `lib/invoice_engine/` contains service-rule and quotation calculation logic.
- `lib/shared/` contains shared UI components and layout widgets.

## Development Setup

### Requirements

- Flutter SDK compatible with Dart `^3.9.0`
- A configured Flutter environment for Android, web, desktop, or iOS

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

Examples:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d android
```

### Analyze the project

```bash
flutter analyze
```

### Run tests

```bash
flutter test
```

### Build Android APK

```bash
flutter build apk
```

## Current Product Characteristics

- Local-first architecture
- Responsive layouts for mobile and desktop
- Business-focused UI for field and office workflows
- No mandatory online dependency for core operations
- Backup and restore support built into the app

## Intended Use Cases

RLX Invoice is suitable for small and medium service businesses that need one app for:

- quotation preparation
- invoice record keeping
- inventory tracking
- expense monitoring
- monthly reporting
- internal staff compensation tracking

## Notes for Maintainers

- The app stores operational data locally using Hive.
- Backup coverage should be updated whenever a new persistent Hive box is added.
- If a new module affects metrics, verify dashboard, finance summary, and restore invalidation behavior.
- If a new responsive layout is added, validate it on both narrow mobile widths and larger desktop widths.

## Repository Goal

This repository is intended to hold the full source for the RLX Invoice app used by Robologicx, including business logic, UI, local data handling, reporting, and backup flows.

## License

This repository currently does not declare a separate license file.
