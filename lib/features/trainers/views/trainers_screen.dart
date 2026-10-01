import 'package:flutter/material.dart';
import 'widgets/trainer_card.dart';
import 'package:gym_system/features/trainers/models/trainer_model.dart';
import 'package:gym_system/core/constants/dummy_data.dart';
import 'package:gym_system/core/theme/colors.dart';

class TrainersScreen extends StatefulWidget {
  const TrainersScreen({Key? key}) : super(key: key);

  @override
  State<TrainersScreen> createState() => _TrainersScreenState();
}

class _TrainersScreenState extends State<TrainersScreen> {
  TrainerModel? _selectedTrainer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trainers', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: DummyData.trainers.length,
                    itemBuilder: (context, index) {
                      return TrainerCard(
                        trainer: DummyData.trainers[index],
                        onTap: () {
                          setState(() {
                            _selectedTrainer = DummyData.trainers[index];
                          });
                        },
                      );
                    },
                  ),
                ),
                if (_selectedTrainer != null) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Schedule & Clients', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(_selectedTrainer!.name, style: const TextStyle(color: AppColors.primary)),
                            const Divider(height: 32),
                            const Text('Today\'s Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildScheduleItem('08:00 AM', 'Morning Yoga', 'Studio A'),
                            _buildScheduleItem('10:00 AM', '1-on-1 Training', 'Weight Room'),
                            _buildScheduleItem('02:00 PM', 'HIIT Session', 'Cardio Zone'),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.message),
                                label: const Text('Message Trainer'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String time, String title, String location) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(time, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                Text(location, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
