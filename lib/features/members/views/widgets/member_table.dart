import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';

class MemberTable extends StatelessWidget {
  final Function(MemberModel) onMemberSelected;

  const MemberTable({Key? key, required this.onMemberSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        children: [
          DataTable(
            showCheckboxColumn: false,
            headingTextStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Plan')),
              DataColumn(label: Text('Expiry')),
              DataColumn(label: Text('Status')),
            ],
            rows: DummyData.members.map((member) {
              final isExpired = member.expiryDate.isBefore(DateTime.now());
              return DataRow(
                onSelectChanged: (_) => onMemberSelected(member),
                cells: [
                  DataCell(Text(member.id, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: AppColors.border, child: Text(member.name[0], style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Text(member.name),
                    ],
                  )),
                  DataCell(Text(member.plan)),
                  DataCell(Text('${member.expiryDate.year}-${member.expiryDate.month.toString().padLeft(2, '0')}-${member.expiryDate.day.toString().padLeft(2, '0')}')),
                  DataCell(
                    Chip(
                      backgroundColor: (member.isPaymentPending || isExpired) ? AppColors.error.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                      label: Text((member.isPaymentPending || isExpired) ? 'Inactive' : 'Active', style: TextStyle(color: (member.isPaymentPending || isExpired) ? AppColors.error : AppColors.success, fontSize: 12)),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
