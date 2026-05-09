import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../../core/models/erp_models.dart';
import '../../../database/local_database.dart';
import '../../finance/application/expense_service.dart';

class TeamService {
  Box<Map>? get _box {
    if (!Hive.isBoxOpen(LocalDatabase.teamMembersBox)) {
      return null;
    }
    return Hive.box<Map>(LocalDatabase.teamMembersBox);
  }

  List<TeamMember> all() {
    final box = _box;
    if (box == null) {
      return const [];
    }

    return box.values.map((value) => TeamMember.fromMap(value)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Stream<List<TeamMember>> watchAll() async* {
    final box = _box;
    if (box == null) {
      yield const [];
      return;
    }

    yield all();
    await for (final _ in box.watch()) {
      yield all();
    }
  }

  Future<void> upsertMember({
    String? id,
    required String name,
    required String role,
    required double monthlySalary,
    required double projectCommission,
    String note = '',
  }) async {
    final box = _box;
    if (box == null) {
      return;
    }

    final now = DateTime.now();
    final member = TeamMember(
      id: id ?? 'tm_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      role: role.trim().isEmpty ? 'Team Member' : role.trim(),
      monthlySalary: monthlySalary,
      projectCommission: projectCommission,
      updatedAt: now,
      note: note.trim(),
    );

    await box.put(member.id, member.toMap());
  }

  Future<void> removeMember(String id) async {
    final box = _box;
    if (box == null) {
      return;
    }
    await box.delete(id);
  }

  Future<int> postMonthlyCompensationExpenses(
    ExpenseService expenseService, {
    DateTime? month,
  }) async {
    final members = all();
    if (members.isEmpty) {
      return 0;
    }

    final target = month ?? DateTime.now();
    final monthKey = DateFormat('yyyyMM').format(target);
    final expenseDate = DateTime(target.year, target.month, 1);
    var created = 0;

    for (final member in members) {
      final salaryAmount = member.monthlySalary;
      final commissionAmount = member.projectCommission;

      if (salaryAmount > 0) {
        final addedSalary = await expenseService.addExpense(
          title: 'Salary - ${member.name}',
          amount: salaryAmount,
          category: 'Team Payroll',
          expenseDate: expenseDate,
          customId: 'team_salary_${member.id}_$monthKey',
          skipIfIdExists: true,
          note: 'Monthly salary for ${member.name} (${member.role})',
        );
        if (addedSalary) {
          created += 1;
        }
      }

      if (commissionAmount > 0) {
        final addedCommission = await expenseService.addExpense(
          title: 'Project Commission - ${member.name}',
          amount: commissionAmount,
          category: 'Team Commission',
          expenseDate: expenseDate,
          customId: 'team_commission_${member.id}_$monthKey',
          skipIfIdExists: true,
          note: 'Monthly project commission for ${member.name}',
        );
        if (addedCommission) {
          created += 1;
        }
      }
    }

    return created;
  }
}

final teamServiceProvider = Provider<TeamService>((ref) {
  return TeamService();
});

final teamMembersProvider = StreamProvider<List<TeamMember>>((ref) {
  final service = ref.watch(teamServiceProvider);
  return service.watchAll();
});
