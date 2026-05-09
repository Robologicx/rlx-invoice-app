import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../../finance/application/expense_service.dart';
import '../application/team_service.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  );

  Future<void> _openMemberDialog([_TeamFormValue? initial]) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final roleController = TextEditingController(
      text: initial?.role ?? 'Team Member',
    );
    final salaryController = TextEditingController(
      text: initial != null ? initial.monthlySalary.toStringAsFixed(0) : '',
    );
    final commissionController = TextEditingController(
      text: initial != null ? initial.projectCommission.toStringAsFixed(0) : '',
    );
    final noteController = TextEditingController(text: initial?.note ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        return AlertDialog(
          title: Text(initial == null ? 'Add Team Member' : 'Edit Team Member'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: screenWidth > 480 ? 420 : screenWidth * 0.82,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: salaryController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monthly Salary',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commissionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Project Commission',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final role = roleController.text.trim();
                final salary =
                    double.tryParse(salaryController.text.trim()) ?? 0;
                final commission =
                    double.tryParse(commissionController.text.trim()) ?? 0;
                final note = noteController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                await ref
                    .read(teamServiceProvider)
                    .upsertMember(
                      id: initial?.id,
                      name: name,
                      role: role,
                      monthlySalary: salary,
                      projectCommission: commission,
                      note: note,
                    );

                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              child: Text(initial == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    roleController.dispose();
    salaryController.dispose();
    commissionController.dispose();
    noteController.dispose();
  }

  Future<void> _postCurrentMonthExpense() async {
    final created = await ref
        .read(teamServiceProvider)
        .postMonthlyCompensationExpenses(
          ref.read(expenseServiceProvider),
          month: DateTime.now(),
        );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == 0
              ? 'No team compensation to add for this month.'
              : 'Added $created team expense entries for this month.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final membersAsync = ref.watch(teamMembersProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Management', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Manage team salaries and project commissions. Add monthly team payout to expenses with one click.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Post monthly salary + commission as expense for finance reports.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _postCurrentMonthExpense,
                        icon: const Icon(Icons.add_card_rounded),
                        label: const Text('Add Month Expense'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openMemberDialog(),
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Add Team Member'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _postCurrentMonthExpense,
                        icon: const Icon(Icons.add_card_rounded),
                        label: const Text('Add Month Expense'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openMemberDialog(),
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Add Team Member'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          membersAsync.when(
            data: (members) {
              final totalSalary = members.fold<double>(
                0,
                (sum, item) => sum + item.monthlySalary,
              );
              final totalCommission = members.fold<double>(
                0,
                (sum, item) => sum + item.projectCommission,
              );
              final totalPayout = totalSalary + totalCommission;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _TeamMetricCard(
                        label: 'Team Members',
                        value: members.length.toString(),
                      ),
                      _TeamMetricCard(
                        label: 'Monthly Salaries',
                        value: _money.format(totalSalary),
                      ),
                      _TeamMetricCard(
                        label: 'Project Commissions',
                        value: _money.format(totalCommission),
                      ),
                      _TeamMetricCard(
                        label: 'Total Monthly Payout',
                        value: _money.format(totalPayout),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (members.isEmpty)
                    GlassPanel(
                      child: Text(
                        'No team members yet. Add your team with salary and commission details.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final item in members)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.role,
                                              style: textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: AppTheme.muted,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          IconButton(
                                            onPressed: () => _openMemberDialog(
                                              _TeamFormValue.fromMember(item),
                                            ),
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                            ),
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            onPressed: () => ref
                                                .read(teamServiceProvider)
                                                .removeMember(item.id),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                            tooltip: 'Delete',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Salary: ${_money.format(item.monthlySalary)}',
                                    style: textTheme.bodyLarge,
                                  ),
                                  Text(
                                    'Commission: ${_money.format(item.projectCommission)}',
                                    style: textTheme.bodyLarge,
                                  ),
                                  Text(
                                    'Total: ${_money.format(item.totalMonthlyPayout)}',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                  if (item.note.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        item.note,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => Text(
              'Failed to load team data: $error',
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMetricCard extends StatelessWidget {
  const _TeamMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth < 600 ? screenWidth - 56 : 250.0;
    return SizedBox(
      width: cardWidth,
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamFormValue {
  const _TeamFormValue({
    required this.id,
    required this.name,
    required this.role,
    required this.monthlySalary,
    required this.projectCommission,
    required this.note,
  });

  final String id;
  final String name;
  final String role;
  final double monthlySalary;
  final double projectCommission;
  final String note;

  factory _TeamFormValue.fromMember(TeamMember member) {
    return _TeamFormValue(
      id: member.id,
      name: member.name,
      role: member.role,
      monthlySalary: member.monthlySalary,
      projectCommission: member.projectCommission,
      note: member.note,
    );
  }
}
