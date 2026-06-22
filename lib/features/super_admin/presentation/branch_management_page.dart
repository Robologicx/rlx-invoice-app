import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../providers/super_admin_providers.dart';

class BranchManagementPage extends ConsumerWidget {
  const BranchManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBranches = ref.watch(allBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showCreateOrEditBranchDialog(context, ref),
          ),
        ],
      ),
      body: allBranches.when(
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No branches yet'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => showCreateOrEditBranchDialog(context, ref),
                    child: const Text('Create First Branch'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: branches
                .map((branch) => BranchCard(branch: branch, ref: ref))
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class BranchCard extends StatelessWidget {
  const BranchCard({super.key, required this.branch, required this.ref});

  final Branch branch;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (branch.status) {
      BranchStatus.active => Colors.green,
      BranchStatus.suspended => Colors.orange,
      BranchStatus.closed => Colors.red,
    };

    final typeLabel = branch.type == BranchType.main
        ? 'Main Branch'
        : 'Franchise (${branch.royaltyPercentage.toStringAsFixed(1)}%)';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 12,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(branch.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(branch.city),
            Text(
              '$typeLabel • ${branch.status.label}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') {
              showBranchDetailsDialog(context, branch);
              return;
            }
            if (value == 'edit') {
              showCreateOrEditBranchDialog(context, ref, branch: branch);
              return;
            }
            if (value == 'delete') {
              showDeleteBranchDialog(context, ref, branch);
              return;
            }
            if (value == 'suspend') {
              updateBranchStatus(context, ref, branch, BranchStatus.suspended);
              return;
            }
            if (value == 'reactivate') {
              updateBranchStatus(context, ref, branch, BranchStatus.active);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (branch.status == BranchStatus.active)
              const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
            if (branch.status == BranchStatus.suspended)
              const PopupMenuItem(value: 'reactivate', child: Text('Reactivate')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

Future<void> showCreateOrEditBranchDialog(
  BuildContext context,
  WidgetRef ref, {
  Branch? branch,
}) async {
  final isEdit = branch != null;
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController(text: branch?.name ?? '');
  final codeController = TextEditingController(text: branch?.code ?? '');
  final cityController = TextEditingController(text: branch?.city ?? '');
  final ownerController = TextEditingController(text: branch?.ownerName ?? '');
  final phoneController = TextEditingController(text: branch?.phone ?? '');
  final emailController = TextEditingController(text: branch?.email ?? '');
  final addressController = TextEditingController(text: branch?.address ?? '');
  final royaltyController = TextEditingController(
    text: (branch?.royaltyPercentage ?? 5).toStringAsFixed(1),
  );

  BranchType selectedType = branch?.type ?? BranchType.franchise;
  BranchStatus selectedStatus = branch?.status ?? BranchStatus.active;

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Branch' : 'Create Branch'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Branch Name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(labelText: 'Branch Code'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: ownerController,
                        decoration: const InputDecoration(labelText: 'Owner Name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BranchType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: BranchType.values
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t.label)))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedType = value;
                            if (selectedType == BranchType.main) {
                              royaltyController.text = '0.0';
                            }
                          });
                        },
                      ),
                      TextFormField(
                        controller: royaltyController,
                        decoration: const InputDecoration(labelText: 'Royalty %'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                      DropdownButtonFormField<BranchStatus>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: BranchStatus.values
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        },
                      ),
                    ],
                  ),
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
                  if (!formKey.currentState!.validate()) {
                    return;
                  }

                  final currentUser = FirebaseAuth.instance.currentUser;
                  final toSave = Branch(
                    id: branch?.id ?? '',
                    name: nameController.text.trim(),
                    code: codeController.text.trim().toUpperCase(),
                    city: cityController.text.trim(),
                    type: selectedType,
                    ownerName: ownerController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    address: addressController.text.trim(),
                    royaltyPercentage: double.parse(royaltyController.text.trim()),
                    status: selectedStatus,
                    mainBranchId: branch?.mainBranchId,
                    createdAt: branch?.createdAt ?? DateTime.now(),
                    createdBy: branch?.createdBy ?? currentUser?.uid ?? 'super_admin',
                  );

                  try {
                    if (isEdit) {
                      await ref
                          .read(branchRepositoryProvider)
                          .updateBranch(toSave.id, toSave);
                    } else {
                      await ref.read(branchRepositoryProvider).createBranch(toSave);
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Failed to save branch: $e')),
                      );
                    }
                  }
                },
                child: Text(isEdit ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      );
    },
  );

  nameController.dispose();
  codeController.dispose();
  cityController.dispose();
  ownerController.dispose();
  phoneController.dispose();
  emailController.dispose();
  addressController.dispose();
  royaltyController.dispose();
}

Future<void> showDeleteBranchDialog(
  BuildContext context,
  WidgetRef ref,
  Branch branch,
) async {
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Branch'),
      content: Text(
        'Are you sure you want to delete ${branch.name}? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await ref.read(branchRepositoryProvider).deleteBranch(branch.id);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            } catch (e) {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void showBranchDetailsDialog(BuildContext context, Branch branch) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(branch.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Code: ${branch.code}'),
          Text('City: ${branch.city}'),
          Text('Type: ${branch.type.label}'),
          Text('Owner: ${branch.ownerName}'),
          Text('Phone: ${branch.phone}'),
          Text('Email: ${branch.email}'),
          Text('Royalty: ${branch.royaltyPercentage.toStringAsFixed(1)}%'),
          Text('Status: ${branch.status.label}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> updateBranchStatus(
  BuildContext context,
  WidgetRef ref,
  Branch branch,
  BranchStatus status,
) async {
  final updated = branch.copyWith(status: status);
  try {
    await ref.read(branchRepositoryProvider).updateBranch(branch.id, updated);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }
}
