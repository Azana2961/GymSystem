import 'package:flutter/material.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';
import 'package:gym_system/core/theme/colors.dart';

class TrainerCard extends StatelessWidget {
  final TrainerModel trainer;
  final VoidCallback onTap;

  const TrainerCard({Key? key, required this.trainer, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(trainer.avatarUrl),
              backgroundColor: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(trainer.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(trainer.specialty, style: const TextStyle(color: AppColors.primary)),
            const SizedBox(height: 16),
            Chip(
              backgroundColor: trainer.isClockedIn ? AppColors.success.withOpacity(0.2) : AppColors.secondary.withOpacity(0.2),
              label: Text(
                trainer.isClockedIn ? 'Clocked In' : 'Clocked Out',
                style: TextStyle(color: trainer.isClockedIn ? AppColors.success : AppColors.textSecondary),
              ),
              side: BorderSide.none,
            ),
          ],
        ),
      ),
    );
  }
}
