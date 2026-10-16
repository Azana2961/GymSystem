import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/theme/colors.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/features/members/views/widgets/member_form_dialog.dart';

class MemberTable extends StatelessWidget {
  final MembersProvider provider;
  final Function(MemberModel) onMemberSelected;
  final MemberModel? selectedMember;

  const MemberTable({
    super.key,
    required this.provider,
    required this.onMemberSelected,
    this.selectedMember,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(48.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final members = provider.paginatedMembers;

    if (members.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(64.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                const Text('No members found', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Try adjusting your filters or search query.', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dataTableTheme: DataTableThemeData(
                            dataRowCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                          ),
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          sortColumnIndex: _getSortColumnIndex(),
                          sortAscending: provider.sortAscending,
                          headingTextStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          columns: [
                            DataColumn(
                              label: const Text('ID'),
                              onSort: (columnIndex, ascending) => provider.setSortOption(MemberSortOption.id),
                            ),
                            DataColumn(
                              label: const Text('Name'),
                              onSort: (columnIndex, ascending) => provider.setSortOption(MemberSortOption.name),
                            ),
                            const DataColumn(label: Text('Plan')),
                            DataColumn(
                              label: const Text('Expiry'),
                              onSort: (columnIndex, ascending) => provider.setSortOption(MemberSortOption.expiryDate),
                            ),
                            const DataColumn(label: Text('Status')),
                            const DataColumn(label: Text('')), // Actions
                          ],
                          rows: members.map((member) {
                            final isExpired = member.expiryDate.isBefore(DateTime.now());
                            final isInactive = !member.isActive || member.isPaymentPending || isExpired;
                            final isExpiringSoon = !isInactive && member.expiryDate.isAfter(DateTime.now()) && member.expiryDate.isBefore(DateTime.now().add(const Duration(days: 7)));
                            final isSelected = selectedMember?.id == member.id;

                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (_) => onMemberSelected(member),
                              color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                                if (states.contains(WidgetState.hovered)) return AppColors.surface.withValues(alpha: 0.5);
                                if (isSelected) return AppColors.primary.withValues(alpha: 0.1);
                                if (isExpiringSoon) return AppColors.warning.withValues(alpha: 0.05);
                                return null;
                              }),
                              cells: [
                                DataCell(Text(member.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                      child: Text(
                                        member.name.isNotEmpty ? member.name[0] : '?',
                                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(member.name),
                                  ],
                                )),
                                DataCell(Text(member.plan)),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${member.expiryDate.year}-${member.expiryDate.month.toString().padLeft(2, '0')}-${member.expiryDate.day.toString().padLeft(2, '0')}'),
                                    if (isExpiringSoon) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                                    ]
                                  ],
                                )),
                                DataCell(
                                  Chip(
                                    backgroundColor: isInactive
                                        ? AppColors.error.withValues(alpha: 0.2)
                                        : AppColors.success.withValues(alpha: 0.2),
                                    label: Text(
                                      isInactive ? 'Inactive' : 'Active',
                                      style: TextStyle(
                                        color: isInactive ? AppColors.error : AppColors.success,
                                        fontSize: 12,
                                      ),
                                    ),
                                    side: BorderSide.none,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                DataCell(
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                    color: AppColors.surface,
                                    onSelected: (value) {
                                      _handleAction(context, value, member);
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'view', child: Text('View Details')),
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      const PopupMenuItem(value: 'renew', child: Text('Renew')),
                                      PopupMenuItem(
                                        value: 'toggle_status',
                                        child: Text(member.isActive ? 'Deactivate' : 'Activate'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete', style: TextStyle(color: AppColors.error)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _buildPagination(),
        ],
      ),
    );
  }

  int _getSortColumnIndex() {
    switch (provider.sortOption) {
      case MemberSortOption.id:
        return 0;
      case MemberSortOption.name:
        return 1;
      case MemberSortOption.expiryDate:
        return 3;
    }
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Rows per page:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: provider.rowsPerPage,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              items: [10, 20, 50].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
              onChanged: (val) {
                if (val != null) provider.setRowsPerPage(val);
              },
            ),
          ),
          const SizedBox(width: 24),
          Text(
            '${provider.currentPage * provider.rowsPerPage + 1}-${((provider.currentPage + 1) * provider.rowsPerPage).clamp(0, provider.totalFilteredMembers)} of ${provider.totalFilteredMembers}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.currentPage > 0 ? () => provider.setPage(provider.currentPage - 1) : null,
            color: provider.currentPage > 0 ? AppColors.textPrimary : AppColors.border,
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.currentPage < provider.totalPages - 1 ? () => provider.setPage(provider.currentPage + 1) : null,
            color: provider.currentPage < provider.totalPages - 1 ? AppColors.textPrimary : AppColors.border,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, MemberModel member) {
    switch (action) {
      case 'view':
        onMemberSelected(member);
        break;
      case 'edit':
        showDialog(
          context: context,
          builder: (context) => MemberFormDialog(provider: provider, memberToEdit: member),
        );
        break;
      case 'renew':
        provider.updateMember(member.copyWith(
          expiryDate: member.expiryDate.isBefore(DateTime.now()) 
              ? DateTime.now().add(const Duration(days: 30))
              : member.expiryDate.add(const Duration(days: 30)),
        ));
        break;
      case 'toggle_status':
        provider.updateMember(member.copyWith(isActive: !member.isActive));
        break;
      case 'delete':
        _showDeleteConfirm(context, member);
        break;
    }
  }

  void _showDeleteConfirm(BuildContext context, MemberModel member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteMember(member.id);
              if (selectedMember?.id == member.id) {
                // We should unselect, but we don't have direct access to setState here unless we pass a clear callback.
                // It's handled gracefully in MembersScreen if the selected member is deleted.
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member.name} deleted'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    textColor: AppColors.primary,
                    onPressed: () => provider.undoDelete(),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
