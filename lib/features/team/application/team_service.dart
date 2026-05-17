import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/erp_models.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../finance/application/expense_service.dart';

class TeamService {
  final FirebaseFirestore _firestore;

  TeamService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  String? _activeUserId() => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('team_members');
  }

  List<TeamMember> all() {
    return const [];
  }

  Stream<List<TeamMember>> watchAll() async* {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      yield const [];
      return;
    }

    yield* _collection(userId).snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => TeamMember.fromMap(doc.data())).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
    );
  }

  Future<void> upsertMember({
    String? id,
    required String name,
    required String role,
    required double monthlySalary,
    required double projectCommission,
    String note = '',
  }) async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
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

    await _collection(userId).doc(member.id).set(member.toMap());
  }

  Future<void> removeMember(String id) async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return;
    }
    await _collection(userId).doc(id).delete();
  }

  Future<List<TeamMember>> _fetchAll() async {
    final userId = _activeUserId();
    if (userId == null || userId.isEmpty) {
      return const [];
    }

    final snapshot = await _collection(userId).get();
    final members = snapshot.docs
        .map((doc) => TeamMember.fromMap(doc.data()))
        .toList();
    members.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return members;
  }

  Future<int> postMonthlyCompensationExpenses(
    ExpenseService expenseService, {
    DateTime? month,
  }) async {
    final members = await _fetchAll();
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
  ref.watch(currentUserProvider);
  return TeamService();
});

final teamMembersProvider = StreamProvider<List<TeamMember>>((ref) {
  final service = ref.watch(teamServiceProvider);
  return service.watchAll();
});
