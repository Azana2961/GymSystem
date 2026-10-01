import 'package:flutter/material.dart';
import 'package:gym_system/features/members/models/member_model.dart';
import 'package:gym_system/core/theme/colors.dart';

class MemberDetail extends StatelessWidget {
  final MemberModel member;

  const MemberDetail({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary,
                  child: Text(member.name[0], style: const TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: Theme.of(context).textTheme.headlineMedium),
                      Text('ID: ${member.id}', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(onPressed: (){}, icon: const Icon(Icons.edit)),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Fitness Stats (Dummy)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('Weight', '75 kg'),
                _buildStat('Height', '180 cm'),
                _buildStat('BMI', '23.1'),
              ],
            ),
            const Divider(height: 48),
            const Text('Membership Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _buildInfoRow('Plan', member.plan),
            _buildInfoRow('Expiry Date', '${member.expiryDate.year}-${member.expiryDate.month}-${member.expiryDate.day}'),
            _buildInfoRow('Payment Status', member.isPaymentPending ? 'Pending' : 'Paid', color: member.isPaymentPending ? AppColors.error : AppColors.success),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Renew Membership'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}
