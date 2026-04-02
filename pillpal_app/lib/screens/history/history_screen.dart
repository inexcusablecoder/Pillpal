import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/dose_log.dart';
import '../../providers/dose_log_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/status_chip.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedDays = 7;
  final List<int> _dayOptions = [7, 14, 30];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoseLogProvider>().fetchHistory(days: _selectedDays);
    });
  }

  void _onDaysChanged(int days) {
    setState(() => _selectedDays = days);
    context.read<DoseLogProvider>().fetchHistory(days: days);
  }

  @override
  Widget build(BuildContext context) {
    final doses = context.watch<DoseLogProvider>();

    // Group logs by date
    final grouped = <String, List<DoseLog>>{};
    for (final log in doses.historyLogs) {
      final key = DateFormat('yyyy-MM-dd').format(log.scheduledDate);
      grouped.putIfAbsent(key, () => []).add(log);
    }
    final dateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => doses.fetchHistory(days: _selectedDays),
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 4),
                    Text(
                      'Your dose history over the last $_selectedDays days',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                    const SizedBox(height: 16),
                    // Day filter chips
                    Row(
                      children: _dayOptions.map((d) {
                        final isSelected = d == _selectedDays;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _onDaysChanged(d),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isSelected ? AppColors.primaryGradient : null,
                                color: isSelected ? null : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(color: AppColors.cardBorder),
                              ),
                              child: Text(
                                '${d}d',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  ],
                ),
              ),
            ),

            // Stats summary
            if (doses.historyLogs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: _buildSummary(doses.historyLogs).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                ),
              ),

            // Content
            if (doses.isLoading && doses.historyLogs.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (doses.historyLogs.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('No history yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dateKey = dateKeys[index];
                      final logs = grouped[dateKey]!;
                      final date = DateTime.parse(dateKey);
                      final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  isToday ? 'Today' : DateFormat('EEE, MMM d').format(date),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildDayBadge(logs),
                              ],
                            ),
                          ),
                          ...logs.map((log) => _buildLogItem(log)),
                        ],
                      ).animate(delay: Duration(milliseconds: 300 + index * 60)).fadeIn().slideX(begin: 0.05);
                    },
                    childCount: dateKeys.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<DoseLog> logs) {
    final taken = logs.where((l) => l.isTaken).length;
    final missed = logs.where((l) => l.isMissed).length;
    final total = taken + missed;
    final adherence = total > 0 ? (taken / total * 100) : 0.0;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Adherence', '${adherence.round()}%', AppColors.primary),
          Container(width: 1, height: 36, color: AppColors.cardBorder),
          _summaryItem('Taken', '$taken', AppColors.success),
          Container(width: 1, height: 36, color: AppColors.cardBorder),
          _summaryItem('Missed', '$missed', AppColors.danger),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildDayBadge(List<DoseLog> logs) {
    final taken = logs.where((l) => l.isTaken).length;
    final total = logs.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$taken/$total',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLogItem(DoseLog log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor(log.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.medication_rounded,
                color: _statusColor(log.status),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.medicineName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    log.scheduledTimeString,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            StatusChip(status: log.status),
          ],
        ),
      ),
    );
  }

  Color _statusColor(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return AppColors.success;
      case DoseStatus.missed:
        return AppColors.danger;
      case DoseStatus.pending:
        return AppColors.warning;
    }
  }
}
