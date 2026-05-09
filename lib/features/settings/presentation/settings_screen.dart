import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/models/erp_models.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../finance/application/expense_service.dart';
import '../../inventory/application/inventory_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final invoicePolicySections = ref.watch(invoicePolicySectionsProvider);
    final invoiceLogoBytes = ref.watch(invoiceLogoBytesProvider);
    final textTheme = Theme.of(context).textTheme;

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
