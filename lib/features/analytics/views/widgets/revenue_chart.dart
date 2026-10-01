import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_system/core/theme/colors.dart';

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue (Last 6 Months)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 20000,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12);
                          String text;
                          switch (value.toInt()) {
                            case 0: text = 'Jan'; break;
                            case 1: text = 'Feb'; break;
                            case 2: text = 'Mar'; break;
                            case 3: text = 'Apr'; break;
                            case 4: text = 'May'; break;
                            case 5: text = 'Jun'; break;
                            default: text = ''; break;
                          }
                          return SideTitleWidget(meta: meta, child: Text(text, style: style));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text('\$${(value / 1000).toInt()}k', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5000,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(color: AppColors.border, strokeWidth: 1);
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBar(0, 12000),
                    _buildBar(1, 14500),
                    _buildBar(2, 13000),
                    _buildBar(3, 16000),
                    _buildBar(4, 15500),
                    _buildBar(5, 18000),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBar(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.primary,
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}
