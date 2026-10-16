import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_system/core/theme/colors.dart';

class FinancialTab extends StatelessWidget {
  const FinancialTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Side: Revenue Bar Chart & Pie Chart
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Revenue Trend (Last 6 Months)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Base Memberships vs. Personal Training (PT)', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 300,
                              child: _buildBarChart(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Payment Methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  const Text('Reconcile physical drawer and accounts.', style: TextStyle(color: AppColors.textSecondary)),
                                  const SizedBox(height: 24),
                                  _buildLegend('Cash', const Color(0xFF66BB6A), '60%'),
                                  const SizedBox(height: 12),
                                  _buildLegend('Credit Card', const Color(0xFF42A5F5), '25%'),
                                  const SizedBox(height: 12),
                                  _buildLegend('Bank Transfer', const Color(0xFFFFA726), '15%'),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 50,
                                    sections: [
                                      PieChartSectionData(color: const Color(0xFF66BB6A), value: 60, title: '60%', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      PieChartSectionData(color: const Color(0xFF42A5F5), value: 25, title: '25%', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      PieChartSectionData(color: const Color(0xFFFFA726), value: 15, title: '15%', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Side: Pending Dues
              Expanded(
                flex: 4,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Pending Dues (Udhaar)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text('Total Unpaid Fees', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              const Text('PKR 145,000', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.error)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Top 10 Outstanding Members', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 10,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.error.withValues(alpha: 0.2),
                                child: Text('M${index + 1}', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              title: Text('Defaulter Name ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: const Text('Overdue by 15 days', style: TextStyle(fontSize: 12)),
                              trailing: Text('PKR ${15000 - (index * 1000)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                              onTap: () {
                                // Clickable list as requested
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 200,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12);
                String text;
                switch (value.toInt()) {
                  case 0: text = 'May'; break;
                  case 1: text = 'Jun'; break;
                  case 2: text = 'Jul'; break;
                  case 3: text = 'Aug'; break;
                  case 4: text = 'Sep'; break;
                  case 5: text = 'Oct'; break;
                  default: text = ''; break;
                }
                return SideTitleWidget(meta: meta, child: Text(text, style: style));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _buildBarGroup(0, 120, 30),
          _buildBarGroup(1, 130, 40),
          _buildBarGroup(2, 110, 35),
          _buildBarGroup(3, 140, 50),
          _buildBarGroup(4, 150, 60),
          _buildBarGroup(5, 170, 65),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double base, double pt) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: base + pt,
          width: 24,
          borderRadius: BorderRadius.circular(4),
          rodStackItems: [
            BarChartRodStackItem(0, base, AppColors.primary),
            BarChartRodStackItem(base, base + pt, AppColors.secondary),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color, String value) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
