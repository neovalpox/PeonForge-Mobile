import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/peonforge_provider.dart';
import '../theme/wc3_theme.dart';
import '../models/models.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PeonForgeProvider>().fetchStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PeonForgeProvider>(builder: (ctx, p, _) {
      return Scaffold(
        backgroundColor: WC3Colors.bgDark,
        appBar: AppBar(
          backgroundColor: WC3Colors.bgCard,
          title: const Text('Statistiques', style: TextStyle(color: WC3Colors.goldLight, fontSize: 16)),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: WC3Colors.goldLight), onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: WC3Colors.goldLight, size: 20),
              onPressed: p.loadingStats ? null : () => p.fetchStats(),
            ),
          ],
        ),
        body: p.loadingStats && p.dailyStats.isEmpty
            ? const Center(child: CircularProgressIndicator(color: WC3Colors.goldLight))
            : p.dailyStats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bar_chart, color: WC3Colors.textDim, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          p.username.isEmpty ? 'Configure un nom d\'utilisateur\npour voir tes stats.' : 'Aucune donnee disponible.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: WC3Colors.textDim, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Summary cards
                      _buildSummary(p.dailyStats),
                      const SizedBox(height: 16),

                      // Tasks per day bar chart
                      _sectionTitle('TACHES PAR JOUR'),
                      _buildTasksChart(p.dailyStats),
                      const SizedBox(height: 20),

                      // Steps per day line chart
                      _sectionTitle('PAS PAR JOUR'),
                      _buildStepsChart(p.dailyStats),
                      const SizedBox(height: 20),
                    ],
                  ),
      );
    });
  }

  Widget _buildSummary(List<DailyStats> stats) {
    final totalTasks = stats.fold<int>(0, (sum, d) => sum + d.tasks);
    final totalSteps = stats.fold<int>(0, (sum, d) => sum + d.steps);
    final totalMinutes = stats.fold<int>(0, (sum, d) => sum + d.workMinutes);
    final totalXp = stats.fold<int>(0, (sum, d) => sum + d.xpGained);
    final activeDays = stats.where((d) => d.tasks > 0).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WC3Colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WC3Colors.goldDark, width: 1.5),
      ),
      child: Column(
        children: [
          const Text('30 DERNIERS JOURS', style: TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statBadge('$totalTasks', 'taches', WC3Colors.green),
              _statBadge(_formatSteps(totalSteps), 'pas', WC3Colors.blue),
              _statBadge('${(totalMinutes / 60).round()}h', 'travail', WC3Colors.goldLight),
              _statBadge('$activeDays', 'jours', WC3Colors.purple),
            ],
          ),
          if (totalXp > 0) ...[
            const SizedBox(height: 8),
            Text('+$totalXp XP gagnes', style: const TextStyle(color: WC3Colors.goldText, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _statBadge(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: WC3Colors.textDim, fontSize: 10)),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(color: WC3Colors.textDim, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTasksChart(List<DailyStats> stats) {
    final maxTasks = stats.fold<int>(1, (m, d) => d.tasks > m ? d.tasks : m);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: WC3Colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WC3Colors.goldDark.withValues(alpha: 0.5)),
      ),
      child: BarChart(
        BarChartData(
          maxY: (maxTasks + 1).toDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => WC3Colors.bgSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = stats[group.x.toInt()];
                return BarTooltipItem(
                  '${_shortDate(day.date)}\n${day.tasks} taches',
                  const TextStyle(color: WC3Colors.goldText, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                  // Show label every 7 days
                  if (i % 7 != 0 && i != stats.length - 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_shortDate(stats[i].date), style: const TextStyle(color: WC3Colors.textDim, fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) return const SizedBox.shrink();
                  return Text('${value.toInt()}', style: const TextStyle(color: WC3Colors.textDim, fontSize: 9));
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: WC3Colors.textDim.withValues(alpha: 0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(stats.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].tasks.toDouble(),
                  color: WC3Colors.green.withValues(alpha: 0.8),
                  width: stats.length > 20 ? 4 : 8,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(3)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStepsChart(List<DailyStats> stats) {
    final maxSteps = stats.fold<int>(1000, (m, d) => d.steps > m ? d.steps : m);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: WC3Colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WC3Colors.goldDark.withValues(alpha: 0.5)),
      ),
      child: LineChart(
        LineChartData(
          maxY: (maxSteps * 1.1).roundToDouble(),
          minY: 0,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => WC3Colors.bgSurface,
              getTooltipItems: (spots) => spots.map((s) {
                final day = stats[s.x.toInt()];
                return LineTooltipItem(
                  '${_shortDate(day.date)}\n${_formatSteps(day.steps)} pas',
                  const TextStyle(color: WC3Colors.goldText, fontSize: 11),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                  if (i % 7 != 0 && i != stats.length - 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_shortDate(stats[i].date), style: const TextStyle(color: WC3Colors.textDim, fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(_formatSteps(value.toInt()), style: const TextStyle(color: WC3Colors.textDim, fontSize: 9));
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: WC3Colors.textDim.withValues(alpha: 0.1), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(stats.length, (i) => FlSpot(i.toDouble(), stats[i].steps.toDouble())),
              isCurved: true,
              curveSmoothness: 0.2,
              color: WC3Colors.blue,
              barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: stats.length > 20 ? 1.5 : 3,
                  color: WC3Colors.blue,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: WC3Colors.blue.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(String date) {
    // Expects "YYYY-MM-DD" format
    final parts = date.split('-');
    if (parts.length >= 3) return '${parts[2]}/${parts[1]}';
    return date;
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return '$steps';
  }
}
