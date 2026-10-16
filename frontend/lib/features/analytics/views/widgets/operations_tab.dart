import 'package:flutter/material.dart';
import 'package:gym_system/core/theme/colors.dart';

class OperationsTab extends StatelessWidget {
  const OperationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Footfall KPI
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Average Daily Footfall', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Average unique physical visits per day.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Text('245 Members', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Heatmap
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Peak Hours Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Darker blocks indicate highest volume of check-ins.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  _buildHeatmap(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = List.generate(18, (i) => i + 6); // 6 AM to 11 PM

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 50) / hours.length;
        return Column(
          children: [
            // X-axis (Hours)
            Row(
              children: [
                const SizedBox(width: 50),
                ...hours.map((h) {
                  return SizedBox(
                    width: cellWidth,
                    child: Text(
                      h > 12 ? '${h - 12}p' : (h == 12 ? '12p' : '${h}a'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // Grid
            ...List.generate(days.length, (dayIdx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    // Y-axis (Day)
                    SizedBox(
                      width: 50,
                      child: Text(days[dayIdx], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    // Cells
                    ...List.generate(hours.length, (hourIdx) {
                      // Mock intensity
                      final h = hours[hourIdx];
                      double intensity = 0.1;
                      if (h >= 17 && h <= 20) { intensity = 0.9; } // Peak evening
                      else if (h >= 7 && h <= 9) { intensity = 0.6; } // Morning rush
                      else if (h == 12 || h == 13) { intensity = 0.4; } // Lunch break
                      
                      // Add some randomness and day variation
                      if (dayIdx >= 5) { intensity *= 0.5; } // Weekends quieter
                      if (dayIdx == 0 && h == 18) { intensity = 1.0; } // Monday evening highest

                      Color cellColor;
                      if (intensity < 0.2) { cellColor = AppColors.border.withValues(alpha: 0.2); }
                      else if (intensity < 0.5) { cellColor = AppColors.primary.withValues(alpha: 0.4); }
                      else if (intensity < 0.8) { cellColor = AppColors.primary.withValues(alpha: 0.7); }
                      else { cellColor = AppColors.primary; }

                      return Tooltip(
                        message: '${days[dayIdx]} ${h > 12 ? '${h - 12} PM' : (h == 12 ? '12 PM' : '$h AM')}: ${(intensity * 100).toInt()} Check-ins',
                        child: Container(
                          width: cellWidth - 2,
                          height: 24,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        );
      }
    );
  }
}
