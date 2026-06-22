import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/models/erp_models.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../finance/application/expense_service.dart';
import 'package:rlx_invoice/features/inventory/application/inventory_controller_v2.dart';
import '../../invoices/application/invoice_ai_service.dart';
import '../../invoices/application/invoice_history_service.dart';
import '../../team/application/team_service.dart';
import '../application/google_drive_backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const int _maxLogoBytes = 2 * 1024 * 1024;
  late final TextEditingController _geminiApiKeyController;
  TextEditingController? _invoiceBusinessNameController;
  TextEditingController? _invoiceAddressController;
  TextEditingController? _invoicePhoneController;
  TextEditingController? _invoiceEmailController;
  TextEditingController? _invoiceWebsiteController;
  bool _showGeminiApiKey = false;

  @override
  void initState() {
    super.initState();
    _geminiApiKeyController = TextEditingController(
      text: ref.read(geminiApiKeyProvider),
    );
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _invoiceBusinessNameController?.dispose();
    _invoiceAddressController?.dispose();
    _invoicePhoneController?.dispose();
    _invoiceEmailController?.dispose();
    _invoiceWebsiteController?.dispose();
    super.dispose();
  }

  TextEditingController get _businessNameController {
    return _invoiceBusinessNameController ??= TextEditingController(
      text: ref.read(invoiceBusinessDetailsProvider).businessName,
    );
  }

  TextEditingController get _addressController {
    return _invoiceAddressController ??= TextEditingController(
      text: ref.read(invoiceBusinessDetailsProvider).address,
    );
  }

  TextEditingController get _phoneController {
    return _invoicePhoneController ??= TextEditingController(
      text: ref.read(invoiceBusinessDetailsProvider).phone,
    );
  }

  TextEditingController get _emailController {
    return _invoiceEmailController ??= TextEditingController(
      text: ref.read(invoiceBusinessDetailsProvider).email,
    );
  }

  TextEditingController get _websiteController {
    return _invoiceWebsiteController ??= TextEditingController(
      text: ref.read(invoiceBusinessDetailsProvider).website,
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await ref.read(firebaseAuthServiceProvider).logout();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final invoicePolicySections = ref.watch(invoicePolicySectionsProvider);
    final invoiceLogoBytes = ref.watch(invoiceLogoBytesProvider);
    final invoiceBusinessDetails = ref.watch(invoiceBusinessDetailsProvider);
    final savedGeminiApiKey = ref.watch(geminiApiKeyProvider);
    const envGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
    final hasGeminiKey =
        savedGeminiApiKey.trim().isNotEmpty ||
        envGeminiApiKey.trim().isNotEmpty;
    final textTheme = Theme.of(context).textTheme;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final currentEmail = authUser?.email ?? '(no email on account)';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Panel', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Manage app appearance, invoice logo, and global invoice policy sections.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 24),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App Theme', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Switch full app between Dark and White theme.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('White'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Sign out from your current account.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                Text('Currently logged in', style: textTheme.labelLarge),
                const SizedBox(height: 6),
                SelectableText(
                  currentEmail,
                  style: textTheme.bodyLarge?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI (Gemini Online)', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Enable online AI prompt understanding using Gemini. When no key is available or internet fails, invoices screen uses offline fallback automatically.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                Chip(
                  avatar: Icon(
                    hasGeminiKey
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: hasGeminiKey ? AppTheme.success : AppTheme.warning,
                    size: 18,
                  ),
                  label: Text(
                    hasGeminiKey
                        ? 'Gemini online is enabled'
                        : 'Gemini key missing. Offline fallback only',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _geminiApiKeyController,
                  obscureText: !_showGeminiApiKey,
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Paste your Gemini API key',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _showGeminiApiKey = !_showGeminiApiKey;
                        });
                      },
                      icon: Icon(
                        _showGeminiApiKey
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        final key = _geminiApiKeyController.text.trim();
                        ref.read(geminiApiKeyProvider.notifier).setKey(key);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              key.isEmpty
                                  ? 'Gemini key cleared. Offline fallback active.'
                                  : 'Gemini key saved. Online AI is ready.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Key'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _geminiApiKeyController.clear();
                        ref.read(geminiApiKeyProvider.notifier).clearKey();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Gemini key removed. Offline fallback active.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Clear Key'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup & Restore (Local File)',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Export all app data into a backup JSON file on your phone and restore anytime from that file.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final message = await ref
                              .read(localBackupServiceProvider)
                              .exportBackupFile();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Backup failed: $error')),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Create Backup File'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final message = await ref
                              .read(localBackupServiceProvider)
                              .restoreFromBackupFile();
                          ref.invalidate(invoiceLogoBytesProvider);
                          ref.invalidate(invoiceBusinessDetailsProvider);
                          ref.invalidate(invoicePolicySectionsProvider);
                          ref.invalidate(enabledServicesProvider);
                          ref.invalidate(customServiceProfilesProvider);
                          ref.invalidate(serviceCatalogEditsProvider);
                          ref.invalidate(themeModeProvider);
                          ref.invalidate(invoiceHistoryProvider);
                          ref.invalidate(inventoryProvider);
                          ref.invalidate(expenseHistoryProvider);
                          ref.invalidate(fixedMonthlyExpensesProvider);
                          ref.invalidate(teamMembersProvider);

                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '$message Restart app if old values are still visible on a screen.',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Restore failed: $error')),
                          );
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Restore From File'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Business Details', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'These details are printed on every generated quotation/invoice PDF.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone No'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _websiteController,
                  decoration: const InputDecoration(labelText: 'Website'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(invoiceBusinessDetailsProvider.notifier)
                            .setDetails(
                              InvoiceBusinessDetails(
                                businessName: _businessNameController.text
                                    .trim(),
                                address: _addressController.text.trim(),
                                phone: _phoneController.text.trim(),
                                email: _emailController.text.trim(),
                                website: _websiteController.text.trim(),
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invoice business details saved successfully.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Details'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _businessNameController.text =
                            invoiceBusinessDetails.businessName;
                        _addressController.text =
                            invoiceBusinessDetails.address;
                        _phoneController.text = invoiceBusinessDetails.phone;
                        _emailController.text = invoiceBusinessDetails.email;
                        _websiteController.text =
                            invoiceBusinessDetails.website;
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reload Saved'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Logo', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'This logo is printed on every generated invoice PDF. Use PNG or JPG.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                if (invoiceLogoBytes == null)
                  Text(
                    'No logo uploaded yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: Image.memory(
                      invoiceLogoBytes,
                      height: 84,
                      cacheWidth: 220,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          withData: true,
                          allowedExtensions: const ['png', 'jpg', 'jpeg'],
                        );
                        final file = result?.files.single;
                        if (file == null) {
                          return;
                        }
                        if (file.size > _maxLogoBytes) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Logo is too large. Please select an image under 2 MB.',
                              ),
                            ),
                          );
                          return;
                        }
                        final bytes = file.bytes;
                        if (bytes == null || bytes.isEmpty) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Unable to read selected logo file.',
                              ),
                            ),
                          );
                          return;
                        }

                        final optimizedBytes = await _optimizeLogo(bytes);
                        if (optimizedBytes == null || optimizedBytes.isEmpty) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Logo processing failed. Try a PNG/JPG image.',
                              ),
                            ),
                          );
                          return;
                        }

                        ref
                            .read(invoiceLogoBytesProvider.notifier)
                            .setLogoBytes(optimizedBytes);
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice logo saved successfully.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Upload Logo'),
                    ),
                    if (invoiceLogoBytes != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          ref
                              .read(invoiceLogoBytesProvider.notifier)
                              .clearLogo();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invoice logo removed.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Remove Logo'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Global Invoice Sections', style: textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'These sections appear on every generated invoice and PDF.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
                for (final section in invoicePolicySections) ...[
                  Text(section.title, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: section.items.join('\n'),
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: '${section.title} items',
                      hintText: 'One line per bullet item',
                    ),
                    onChanged: (value) {
                      final lines = value
                          .split('\n')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList();
                      ref
                          .read(invoicePolicySectionsProvider.notifier)
                          .updateSection(section.title, lines);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Firestore Structure', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final collection in firestoreCollections)
                      Chip(label: Text(collection)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Made by Robologicx', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'www.robologicx.org',
                  style: textTheme.bodyLarge?.copyWith(color: AppTheme.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<Uint8List?> _optimizeLogo(Uint8List sourceBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(sourceBytes, targetWidth: 900);
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
