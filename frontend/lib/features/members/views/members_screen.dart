import 'package:flutter/material.dart';
import 'package:gym_system/features/members/providers/members_provider.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'widgets/member_table.dart';
import 'widgets/member_detail.dart';
import 'widgets/members_header.dart';
import 'widgets/summary_cards.dart';
import 'widgets/members_filter_bar.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final MembersProvider _provider = MembersProvider();

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _provider,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MembersHeader(provider: _provider),
              const SizedBox(height: 24),
              SummaryCards(provider: _provider),
              const SizedBox(height: 24),
              MembersFilterBar(provider: _provider),
              const SizedBox(height: 16),
              Expanded(
                child: MemberTable(
                  provider: _provider,
                  onMemberSelected: (member) {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog.fullscreen(
                        child: MemberDetail(
                          member: member,
                          provider: _provider,
                          onClose: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
