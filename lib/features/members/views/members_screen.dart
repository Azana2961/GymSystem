import 'package:flutter/material.dart';
import 'widgets/member_table.dart';
import 'widgets/member_detail.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/theme/colors.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  MemberModel? _selectedMember;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Members', style: Theme.of(context).textTheme.headlineLarge),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search members...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: MemberTable(
                    onMemberSelected: (member) {
                      setState(() {
                        _selectedMember = member;
                      });
                    },
                  ),
                ),
                if (_selectedMember != null) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: MemberDetail(member: _selectedMember!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
