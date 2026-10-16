import 'package:flutter/material.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';
import 'package:gym_system/core/theme/colors.dart';

class TrainerCard extends StatelessWidget {
  final TrainerModel trainer;
  final VoidCallback onTap;

  const TrainerCard({
    super.key,
    required this.trainer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = trainer.name.trim().isNotEmpty ? trainer.name.trim()[0] : 'T';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                trainer.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                trainer.specialty,
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trainer.isClockedIn
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trainer.isClockedIn ? 'Clocked In' : 'Clocked Out',
                    style: TextStyle(
                      color: trainer.isClockedIn ? AppColors.success : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
