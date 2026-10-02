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
  MemberModel? _selectedMember;

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
        if (_selectedMember != null && 
            !_provider.allMembers.any((m) => m.id == _selectedMember!.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedMember = null);
          });
        }
        
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 900;
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: isWide && _selectedMember != null ? 2 : 1,
                          child: MemberTable(
                            provider: _provider,
                            selectedMember: _selectedMember,
                            onMemberSelected: (member) {
                              setState(() {
                                _selectedMember = member;
                              });
                              if (!isWide) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => Padding(
                                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24),
                                    child: MemberDetail(
                                      member: member,
                                      provider: _provider,
                                      onClose: () => Navigator.pop(context),
                                    ),
                                  ),
                                ).whenComplete(() {
                                  if (mounted && _selectedMember?.id == member.id) {
                                    setState(() => _selectedMember = null);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        if (_selectedMember != null && isWide) ...[
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              },
                              child: MemberDetail(
                                key: ValueKey(_selectedMember!.id),
                                member: _selectedMember!,
                                provider: _provider,
                                onClose: () => setState(() => _selectedMember = null),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
