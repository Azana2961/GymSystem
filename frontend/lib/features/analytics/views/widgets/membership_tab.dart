import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_system/core/theme/colors.dart';

class MembershipTab extends StatelessWidget {
  const MembershipTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Acquisition vs Churn Line Chart
              Expanded(
                flex: 6,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Acquisition vs. Churn (Last 6 Months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildLegend('New Sign-ups', AppColors.primary),
                            const SizedBox(width: 16),
                            _buildLegend('Expired/Unrenewed', AppColors.error),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 300,
                          child: _buildLineChart(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Right: Plan Popularity Donut Chart
              Expanded(
                flex: 4,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Plan Popularity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Subscription tier distribution.', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('100%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  Text('Total', style: TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 60,
                                  sections: [
                                    PieChartSectionData(color: AppColors.primary, value: 60, title: '60%', radius: 20, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                    PieChartSectionData(color: const Color(0xFF42A5F5), value: 30, title: '30%', radius: 20, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    PieChartSectionData(color: const Color(0xFFFFA726), value: 10, title: '10%', radius: 20, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildLegendPercent('1-Month Plan', AppColors.primary, '60%'),
                        const SizedBox(height: 12),
                        _buildLegendPercent('3-Month Plan', const Color(0xFF42A5F5), '30%'),
                        const SizedBox(height: 12),
                        _buildLegendPercent('Annual Plan', const Color(0xFFFFA726), '10%'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Active Member Count Historical Graph
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Member Count (Year to Date)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Total active members on the floor month-by-month.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 250,
                    child: _buildAreaChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildLegendPercent(String label, Color color, String value) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12);
                String text;
                switch (value.toInt()) {
                  case 0: text = 'May'; break;
                  case 1: text = 'Jun'; break;
                  case 2: text = 'Jul'; break;
                  case 3: text = 'Aug'; break;
                  case 4: text = 'Sep'; break;
                  case 5: text = 'Oct'; break;
                  default: return const SizedBox();
                }
                return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
              },
              interval: 1,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 5,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(0, 40), FlSpot(1, 55), FlSpot(2, 45), FlSpot(3, 70), FlSpot(4, 65), FlSpot(5, 85)],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: const [FlSpot(0, 30), FlSpot(1, 25), FlSpot(2, 35), FlSpot(3, 20), FlSpot(4, 15), FlSpot(5, 25)],
            isCurved: true,
            color: AppColors.error,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12);
                String text;
                switch (value.toInt()) {
                  case 0: text = 'Jan'; break;
                  case 2: text = 'Mar'; break;
                  case 4: text = 'May'; break;
                  case 6: text = 'Jul'; break;
                  case 8: text = 'Sep'; break;
                  case 10: text = 'Nov'; break;
                  default: return const SizedBox();
                }
                return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
              },
              interval: 1,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: 500,
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(0, 200), FlSpot(1, 220), FlSpot(2, 250), FlSpot(3, 240), FlSpot(4, 280), FlSpot(5, 300), FlSpot(6, 310), FlSpot(7, 340), FlSpot(8, 360), FlSpot(9, 390), FlSpot(10, 420), FlSpot(11, 450)],
            isCurved: true,
            color: const Color(0xFF64B5F6),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: const Color(0xFF64B5F6).withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }
}
