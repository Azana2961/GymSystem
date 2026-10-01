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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                foregroundImage: NetworkImage(trainer.avatarUrl),
                onForegroundImageError: (_, stackTrace) {
                  // Gracefully fall back to child initial on network/CORS error
                },
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                trainer.name,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                trainer.specialty,
                style: const TextStyle(color: AppColors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Chip(
                backgroundColor: trainer.isClockedIn
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.secondary.withValues(alpha: 0.2),
                label: Text(
                  trainer.isClockedIn ? 'Clocked In' : 'Clocked Out',
                  style: TextStyle(
                    color: trainer.isClockedIn ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
                side: BorderSide.none,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
