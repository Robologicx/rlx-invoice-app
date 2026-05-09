import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/models/erp_models.dart';
import '../../../shared/presentation/widgets/glass_panel.dart';
import '../application/expense_service.dart';
import '../application/finance_pdf_exporter.dart';
import '../application/finance_report_provider.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  DateTime _expenseDate = DateTime.now();

  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  );
  final DateFormat _date = DateFormat('dd MMM yyyy');
  final DateFormat _month = DateFormat('MMM yyyy');
  bool _didAutoSyncFixedExpenses = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _categoryController = TextEditingController(text: 'Operations');
    _noteController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSyncFixedExpenses();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _expenseDate,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _expenseDate = picked;
    });
  }

  Future<void> _exportToPdf(WidgetRef ref) async {
    final selectedMonth = ref.read(selectedReportMonthProvider);
    final financeAsync = ref.read(financeSummaryProvider);
    final invoicesAsync = ref.read(selectedMonthInvoicesProvider);
    final expensesAsync = ref.read(selectedMonthExpensesProvider);

    final finance = financeAsync.valueOrNull;
    final invoices = invoicesAsync.valueOrNull;
    final expenses = expensesAsync.valueOrNull;

    if (finance == null || invoices == null || expenses == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Loading report data...')));
      return;
    }

    final monthReport = finance.monthlyReports.firstWhere(
      (item) =>
          item.month.year == selectedMonth.year &&
          item.month.month == selectedMonth.month,
      orElse: () => MonthlyFinanceReport(
        month: selectedMonth,
        totalSales: 0,
        totalExpenses: 0,
        profit: 0,
        invoiceCount: 0,
        expenseCount: 0,
      ),
    );

    try {
      final pdfDoc = await FinancePdfExporter.generate(
        summary: finance,
        monthReport: monthReport,
        invoices: invoices,
        expenses: expenses,
      );

      if (!mounted) {
        return;
      }
      final pdfBytes = await pdfDoc.save();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'rlx-report-${DateFormat('yyyy-MM').format(selectedMonth)}.pdf',
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF exported successfully!')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export PDF: $error')));
    }
  }

  void _changeMonth(int monthDelta, WidgetRef ref) {
    final current = ref.read(selectedReportMonthProvider);
    ref.read(selectedReportMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + monthDelta,
    );
  }

  Future<void> _addExpense() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final category = _categoryController.text.trim();
    final note = _noteController.text.trim();

    if (title.isEmpty || amount <= 0) {
      return;
    }

    await ref
        .read(expenseServiceProvider)
        .addExpense(
          title: title,
          amount: amount,
          category: category,
          expenseDate: _expenseDate,
          note: note,
        );

    _titleController.clear();
    _amountController.clear();
    _noteController.clear();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Expense added.')));
  }

  Future<void> _autoSyncFixedExpenses() async {
    if (_didAutoSyncFixedExpenses || !mounted) {
      return;
    }
    _didAutoSyncFixedExpenses = true;
    final created = await ref
        .read(expenseServiceProvider)
        .syncFixedExpensesForMonth(month: DateTime.now());
    if (!mounted || created <= 0) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auto-added $created fixed monthly expenses.')),
    );
  }

  Future<void> _syncFixedExpensesNow() async {
    final created = await ref
        .read(expenseServiceProvider)
        .syncFixedExpensesForMonth(month: DateTime.now());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created == 0
              ? 'No new fixed monthly expense to add.'
              : 'Added $created fixed monthly expense entries.',
        ),
      ),
    );
  }

  Future<void> _openFixedExpenseDialog([FixedMonthlyExpense? initial]) async {
    final titleController = TextEditingController(text: initial?.title ?? '');
    final amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(0),
    );
    final categoryController = TextEditingController(
      text: initial?.category ?? 'Fixed Expense',
    );
    final noteController = TextEditingController(text: initial?.note ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final isCompact = screenWidth < 520;
        return AlertDialog(
          title: Text(
            initial == null
                ? 'Add Fixed Monthly Expense'
                : 'Edit Fixed Monthly Expense',
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: isCompact ? screenWidth * 0.82 : 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
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
                final title = titleController.text.trim();
                final amount =
                    double.tryParse(amountController.text.trim()) ?? 0;
                final category = categoryController.text.trim();
                final note = noteController.text.trim();
                if (title.isEmpty || amount <= 0) {
                  return;
                }

                await ref
                    .read(expenseServiceProvider)
                    .upsertFixedMonthlyExpense(
                      id: initial?.id,
                      title: title,
                      amount: amount,
                      category: category,
                      note: note,
                      isActive: initial?.isActive ?? true,
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
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final financeAsync = ref.watch(financeSummaryProvider);
    final expensesAsync = ref.watch(expenseHistoryProvider);
    final fixedExpensesAsync = ref.watch(fixedMonthlyExpensesProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Finance & Reports', style: textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Track expenses, monitor total sales, and review monthly profit trends.',
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 20),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Expense', style: textTheme.titleLarge),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Expense Title'),
                ),
                const SizedBox(height: 10),
                if (isCompact) ...[
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (isCompact) ...[
                  Text(
                    'Expense Date: ${_date.format(_expenseDate)}',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickExpenseDate,
                    icon: const Icon(Icons.date_range_rounded),
                    label: const Text('Pick Date'),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Expense Date: ${_date.format(_expenseDate)}',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickExpenseDate,
                        icon: const Icon(Icons.date_range_rounded),
                        label: const Text('Pick Date'),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _addExpense,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Expense'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fixed Monthly Expenses', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'These are automatically added each month as expenses.',
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _syncFixedExpensesNow,
                        icon: const Icon(Icons.autorenew_rounded),
                        label: const Text('Sync This Month'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openFixedExpenseDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Fixed'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _syncFixedExpensesNow,
                        icon: const Icon(Icons.autorenew_rounded),
                        label: const Text('Sync This Month'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openFixedExpenseDialog(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Fixed'),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                fixedExpensesAsync.when(
                  data: (fixedItems) {
                    if (fixedItems.isEmpty) {
                      return Text(
                        'No fixed monthly expenses yet.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        for (final item in fixedItems)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Switch(
                                  value: item.isActive,
                                  onChanged: (value) => ref
                                      .read(expenseServiceProvider)
                                      .setFixedMonthlyExpenseActive(
                                        item.id,
                                        value,
                                      ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.title} • ${item.category}',
                                        style: textTheme.bodyLarge,
                                      ),
                                      Text(
                                        _money.format(item.amount),
                                        style: textTheme.titleMedium?.copyWith(
                                          color: AppTheme.accent,
                                        ),
                                      ),
                                      if (item.note.isNotEmpty)
                                        Text(
                                          item.note,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _openFixedExpenseDialog(item),
                                  icon: const Icon(Icons.edit_rounded),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  onPressed: () => ref
                                      .read(expenseServiceProvider)
                                      .deleteFixedMonthlyExpense(item.id),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, _) => Text(
                    'Failed to load fixed expenses: $error',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          financeAsync.when(
            data: (summary) {
              final monthReport = summary.currentMonthReport;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FinanceCard(
                        title: 'This Month Sales',
                        value: _money.format(monthReport.totalSales),
                        color: AppTheme.success,
                        icon: Icons.point_of_sale_rounded,
                      ),
                      _FinanceCard(
                        title: 'This Month Expense',
                        value: _money.format(monthReport.totalExpenses),
                        color: AppTheme.warning,
                        icon: Icons.money_off_csred_rounded,
                      ),
                      _FinanceCard(
                        title: monthReport.profit >= 0
                            ? 'This Month Profit'
                            : 'This Month Loss',
                        value: _money.format(monthReport.profit.abs()),
                        color: monthReport.profit >= 0
                            ? AppTheme.accent
                            : Colors.redAccent,
                        icon: monthReport.profit >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monthly report resets automatically on the 1st day of each month.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => Text(
              'Failed to calculate finance summary: $error',
              style: textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
          ),
          const SizedBox(height: 20),
          Consumer(
            builder: (context, consumerRef, _) {
              final selectedMonth = consumerRef.watch(
                selectedReportMonthProvider,
              );
              return GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report Selection', style: textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (isCompact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _changeMonth(-1, consumerRef),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Text(
                                  DateFormat('MMMM yyyy').format(selectedMonth),
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _changeMonth(1, consumerRef),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _exportToPdf(consumerRef),
                            icon: const Icon(Icons.file_download_rounded),
                            label: const Text('Export PDF'),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _changeMonth(-1, consumerRef),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'MMMM yyyy',
                                    ).format(selectedMonth),
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyLarge,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeMonth(1, consumerRef),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _exportToPdf(consumerRef),
                            icon: const Icon(Icons.file_download_rounded),
                            label: const Text('Export PDF'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;

              final monthlyReportPanel = GlassPanel(
                child: financeAsync.when(
                  data: (summary) {
                    if (summary.monthlyReports.isEmpty) {
                      return Text(
                        'No monthly reports yet. Add invoices and expenses to see trends.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      );
                    }

                    final reports = summary.monthlyReports.take(12).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Reports', style: textTheme.titleLarge),
                        const SizedBox(height: 12),
                        ...reports.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.outline),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: isCompact
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _month.format(item.month),
                                          style: textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Invoices: ${item.invoiceCount}  •  Expenses: ${item.expenseCount}',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Sales: ${_money.format(item.totalSales)}',
                                          style: textTheme.bodyLarge,
                                        ),
                                        Text(
                                          'Expense: ${_money.format(item.totalExpenses)}',
                                          style: textTheme.bodyLarge,
                                        ),
                                        Text(
                                          'Profit: ${_money.format(item.profit)}',
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                color: item.profit >= 0
                                                    ? AppTheme.success
                                                    : Colors.redAccent,
                                              ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _month.format(item.month),
                                                style: textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Invoices: ${item.invoiceCount}  •  Expenses: ${item.expenseCount}',
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color: AppTheme.muted,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Sales: ${_money.format(item.totalSales)}',
                                              style: textTheme.bodyLarge,
                                            ),
                                            Text(
                                              'Expense: ${_money.format(item.totalExpenses)}',
                                              style: textTheme.bodyLarge,
                                            ),
                                            Text(
                                              'Profit: ${_money.format(item.profit)}',
                                              style: textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: item.profit >= 0
                                                        ? AppTheme.success
                                                        : Colors.redAccent,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, _) => Text(
                    'Failed to load monthly reports: $error',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              );

              final expenseListPanel = GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expense History', style: textTheme.titleLarge),
                    const SizedBox(height: 12),
                    expensesAsync.when(
                      data: (records) {
                        if (records.isEmpty) {
                          return Text(
                            'No expenses added yet.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final item in records.take(20))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: AppTheme.warning,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.title} • ${item.category}',
                                            style: textTheme.bodyLarge,
                                          ),
                                          Text(
                                            '${_date.format(item.expenseDate)} • ${_money.format(item.amount)}',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.muted,
                                                ),
                                          ),
                                          if (item.note.isNotEmpty)
                                            Text(
                                              item.note,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: AppTheme.muted,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => ref
                                          .read(expenseServiceProvider)
                                          .deleteExpense(item.id),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (error, _) => Text(
                        'Failed to load expenses: $error',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: monthlyReportPanel),
                    const SizedBox(width: 12),
                    Expanded(child: expenseListPanel),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  monthlyReportPanel,
                  const SizedBox(height: 12),
                  expenseListPanel,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth < 720 ? screenWidth - 40 : 260.0;

    return SizedBox(
      width: cardWidth,
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: textTheme.bodyLarge),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
