import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/erp_models.dart';
import '../../invoices/application/invoice_history_service.dart';
import 'expense_service.dart';

/// Selected month for PDF export (defaults to current month)
final selectedReportMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Get invoices for selected month
final selectedMonthInvoicesProvider = Provider<AsyncValue<List<InvoiceRecord>>>(
  (ref) {
    final invoicesAsync = ref.watch(invoiceHistoryProvider);
    final selectedMonth = ref.watch(selectedReportMonthProvider);

    return invoicesAsync.whenData((invoices) {
      final deduped = <String, InvoiceRecord>{};
      for (final record in invoices.where((item) => item.isInvoice)) {
        final key = record.invoiceNo.isNotEmpty
            ? record.invoiceNo
            : (record.parentQuotationNo.isNotEmpty
                  ? record.parentQuotationNo
                  : record.quotationNo);
        final existing = deduped[key];
        if (existing == null ||
            record.generatedAt.isAfter(existing.generatedAt)) {
          deduped[key] = record;
        }
      }

      return deduped.values.where((invoice) {
        final invoiceMonth = DateTime(
          invoice.generatedAt.year,
          invoice.generatedAt.month,
        );
        return invoiceMonth.year == selectedMonth.year &&
            invoiceMonth.month == selectedMonth.month;
      }).toList()..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    });
  },
);

/// Get expenses for selected month
final selectedMonthExpensesProvider = Provider<AsyncValue<List<ExpenseRecord>>>(
  (ref) {
    final expensesAsync = ref.watch(expenseHistoryProvider);
    final selectedMonth = ref.watch(selectedReportMonthProvider);

    return expensesAsync.whenData((expenses) {
      return expenses.where((expense) {
        final expenseMonth = DateTime(
          expense.expenseDate.year,
          expense.expenseDate.month,
        );
        return expenseMonth.year == selectedMonth.year &&
            expenseMonth.month == selectedMonth.month;
      }).toList()..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    });
  },
);

final financeSummaryProvider = Provider<AsyncValue<FinanceSummary>>((ref) {
  final invoicesAsync = ref.watch(invoiceHistoryProvider);
  final expensesAsync = ref.watch(expenseHistoryProvider);

  if (invoicesAsync.isLoading || expensesAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final invoiceRecords = invoicesAsync.valueOrNull ?? const <InvoiceRecord>[];
  final expenseRecords = expensesAsync.valueOrNull ?? const <ExpenseRecord>[];

  final invoiceMap = <String, InvoiceRecord>{};
  for (final record in invoiceRecords.where((item) => item.isInvoice)) {
    final key = record.invoiceNo.isNotEmpty
        ? record.invoiceNo
        : (record.parentQuotationNo.isNotEmpty
              ? record.parentQuotationNo
              : record.quotationNo);
    final existing = invoiceMap[key];
    if (existing == null || record.generatedAt.isAfter(existing.generatedAt)) {
      invoiceMap[key] = record;
    }
  }

  final invoices = invoiceMap.values.toList();
  final salesTotal = invoices.fold<double>(0, (sum, item) => sum + item.total);
  final expenseTotal = expenseRecords.fold<double>(
    0,
    (sum, item) => sum + item.amount,
  );

  final monthBuckets = <String, _MonthBucket>{};

  for (final invoice in invoices) {
    final month = DateTime(invoice.generatedAt.year, invoice.generatedAt.month);
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final bucket = monthBuckets.putIfAbsent(
      key,
      () => _MonthBucket(month: month),
    );
    bucket.sales += invoice.total;
    bucket.invoiceCount += 1;
  }

  for (final expense in expenseRecords) {
    final month = DateTime(expense.expenseDate.year, expense.expenseDate.month);
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final bucket = monthBuckets.putIfAbsent(
      key,
      () => _MonthBucket(month: month),
    );
    bucket.expenses += expense.amount;
    bucket.expenseCount += 1;
  }

  final monthlyReports =
      monthBuckets.values
          .map(
            (item) => MonthlyFinanceReport(
              month: item.month,
              totalSales: item.sales,
              totalExpenses: item.expenses,
              profit: item.sales - item.expenses,
              invoiceCount: item.invoiceCount,
              expenseCount: item.expenseCount,
            ),
          )
          .toList()
        ..sort((a, b) => b.month.compareTo(a.month));

  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final previousMonth = now.month == 1
      ? DateTime(now.year - 1, 12)
      : DateTime(now.year, now.month - 1);

  MonthlyFinanceReport currentMonthReport = MonthlyFinanceReport(
    month: currentMonth,
    totalSales: 0,
    totalExpenses: 0,
    profit: 0,
    invoiceCount: 0,
    expenseCount: 0,
  );
  MonthlyFinanceReport? previousMonthReport;

  for (final item in monthlyReports) {
    if (item.month.year == currentMonth.year &&
        item.month.month == currentMonth.month) {
      currentMonthReport = item;
    }
    if (item.month.year == previousMonth.year &&
        item.month.month == previousMonth.month) {
      previousMonthReport = item;
    }
  }

  return AsyncValue.data(
    FinanceSummary(
      totalSales: salesTotal,
      totalExpenses: expenseTotal,
      totalProfit: salesTotal - expenseTotal,
      monthlyReports: monthlyReports,
      currentMonthReport: currentMonthReport,
      previousMonthReport: previousMonthReport,
    ),
  );
});

class _MonthBucket {
  _MonthBucket({required this.month});

  final DateTime month;
  double sales = 0;
  double expenses = 0;
  int invoiceCount = 0;
  int expenseCount = 0;
}
