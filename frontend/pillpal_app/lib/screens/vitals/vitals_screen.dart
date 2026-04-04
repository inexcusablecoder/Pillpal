import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/glass_card.dart';
import '../../providers/localization_provider.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  String _selectedRange = '7d'; // '7d', '30d', '90d'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final memberId = context.read<FamilyProvider>().activeMemberId;
      context.read<VitalsProvider>().fetchVitals(memberId: memberId);
    });
  }

  void _showAddVitalModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddVitalModal(),
    );
  }

  int get _daysRange {
    switch (_selectedRange) {
      case '30d':
        return 30;
      case '90d':
        return 90;
      default:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vitalsProvider = context.watch<VitalsProvider>();
    final family = context.watch<FamilyProvider>();
    final loc = context.watch<LocalizationProvider>();
    final memberName = family.isViewingSelf ? '' : ' — ${family.activeMember.name}';

    // Re-fetch when active member changes
    if (vitalsProvider.currentMemberId != family.activeMemberId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vitalsProvider.fetchVitals(memberId: family.activeMemberId);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddVitalModal(context),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ).animate().scale(delay: 500.ms, begin: const Offset(0.5, 0.5)),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${loc.translate('vitals_title')}$memberName',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                  const SizedBox(height: 8),
                  Text(
                    loc.translate('vitals_subtitle'),
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                ],
              ),
            ),
          ),

          // Date range selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  _rangeChip('7d', '7 Days'),
                  const SizedBox(width: 8),
                  _rangeChip('30d', '30 Days'),
                  const SizedBox(width: 8),
                  _rangeChip('90d', '90 Days'),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
            ),
          ),

          if (vitalsProvider.vitals.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 24,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite_border_rounded, size: 64, color: AppColors.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      loc.translate('no_vitals_title'),
                      style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.translate('no_vitals_subtitle'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildVitalChartCard(
                    title: loc.translate('blood_pressure'),
                    type: 'bp',
                    icon: Icons.favorite_rounded,
                    color: AppColors.danger,
                    secondaryColor: AppColors.coral,
                    provider: vitalsProvider,
                    unit: 'mmHg',
                    isBP: true,
                    loc: loc,
                  ),
                  const SizedBox(height: 16),
                  _buildVitalChartCard(
                    title: loc.translate('heart_rate'),
                    type: 'hr',
                    icon: Icons.monitor_heart_rounded,
                    color: AppColors.primary,
                    secondaryColor: AppColors.primaryLight,
                    provider: vitalsProvider,
                    unit: 'BPM',
                    loc: loc,
                  ),
                  const SizedBox(height: 16),
                  _buildVitalChartCard(
                    title: loc.translate('weight'),
                    type: 'weight',
                    icon: Icons.scale_rounded,
                    color: AppColors.success,
                    secondaryColor: const Color(0xFF6EE7B7),
                    provider: vitalsProvider,
                    unit: 'lbs',
                    loc: loc,
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rangeChip(String value, String label) {
    final isSelected = _selectedRange == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildVitalChartCard({
    required String title,
    required String type,
    required IconData icon,
    required Color color,
    required Color secondaryColor,
    required VitalsProvider provider,
    required String unit,
    required LocalizationProvider loc,
    bool isBP = false,
  }) {
    final allLogs = provider.getLogsByType(type);
    if (allLogs.isEmpty) return const SizedBox.shrink();

    // Filter to selected range
    final cutoff = DateTime.now().subtract(Duration(days: _daysRange));
    final logs = allLogs.where((l) => l.timestamp.isAfter(cutoff)).toList();
    // Sort chronologically for chart
    logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (logs.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              '$title — no data in this range',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final latest = allLogs.first; // allLogs is sorted newest-first
    final trendInfo = _getTrend(logs, isBP: isBP);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${logs.length} readings  •  Last: ${DateFormat('MMM d').format(latest.timestamp)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Trend badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: trendInfo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendInfo.icon, size: 14, color: trendInfo.color),
                    const SizedBox(width: 4),
                    Text(
                      trendInfo.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendInfo.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Latest reading
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest.value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 180,
            child: isBP
                ? _buildBPChart(logs, color, secondaryColor)
                : _buildSingleLineChart(logs, color, secondaryColor, type),
          ),

          // Legend for BP
          if (isBP) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(color, loc.translate('systolic')),
                const SizedBox(width: 24),
                _legendDot(secondaryColor, loc.translate('diastolic')),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08);
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─── Single-value line chart (HR, Weight) ────────────────────────
  Widget _buildSingleLineChart(List<VitalLog> logs, Color color, Color secondaryColor, String type) {
    final spots = <FlSpot>[];
    for (int i = 0; i < logs.length; i++) {
      final val = double.tryParse(logs[i].value) ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final values = spots.map((s) => s.y).toList();
    final minY = (values.reduce(min) * 0.9).floorToDouble();
    final maxY = (values.reduce(max) * 1.1).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _niceInterval(maxY - minY),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [6, 4],
          ),
        ),
        titlesData: _buildTitles(logs, minY, maxY),
        borderData: FlBorderData(show: false),
        lineTouchData: _buildTouchData(logs, color),
        lineBarsData: [
          _lineBarData(spots, color, secondaryColor),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ─── BP dual-line chart (systolic + diastolic) ───────────────────
  Widget _buildBPChart(List<VitalLog> logs, Color sysColor, Color diaColor) {
    final sysSpots = <FlSpot>[];
    final diaSpots = <FlSpot>[];

    for (int i = 0; i < logs.length; i++) {
      final parts = logs[i].value.split('/');
      final sys = double.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 120;
      final dia = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 80;
      sysSpots.add(FlSpot(i.toDouble(), sys));
      diaSpots.add(FlSpot(i.toDouble(), dia));
    }
    if (sysSpots.isEmpty) return const SizedBox.shrink();

    final allValues = [...sysSpots.map((s) => s.y), ...diaSpots.map((s) => s.y)];
    final minY = (allValues.reduce(min) * 0.85).floorToDouble();
    final maxY = (allValues.reduce(max) * 1.1).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _niceInterval(maxY - minY),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.cardBorder.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [6, 4],
          ),
        ),
        titlesData: _buildTitles(logs, minY, maxY),
        borderData: FlBorderData(show: false),
        lineTouchData: _buildBPTouchData(logs, sysColor, diaColor),
        lineBarsData: [
          _lineBarData(sysSpots, sysColor, sysColor),
          _lineBarData(diaSpots, diaColor, diaColor, isDashed: true),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  LineChartBarData _lineBarData(List<FlSpot> spots, Color color, Color gradientEnd, {bool isDashed = false}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dashArray: isDashed ? [6, 4] : null,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3.5,
            color: Colors.white,
            strokeWidth: 2.5,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: !isDashed,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  FlTitlesData _buildTitles(List<VitalLog> logs, double minY, double maxY) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: _bottomInterval(logs.length),
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= logs.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                DateFormat('M/d').format(logs[idx].timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          interval: _niceInterval(maxY - minY),
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(List<VitalLog> logs, Color color) {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => AppColors.textPrimary,
        tooltipRoundedRadius: 12,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final idx = spot.x.toInt();
            final date = idx < logs.length
                ? DateFormat('MMM d, y').format(logs[idx].timestamp)
                : '';
            return LineTooltipItem(
              '${spot.y.toStringAsFixed(0)}\n',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              children: [
                TextSpan(
                  text: date,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            );
          }).toList();
        },
      ),
    );
  }

  LineTouchData _buildBPTouchData(List<VitalLog> logs, Color sysColor, Color diaColor) {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => AppColors.textPrimary,
        tooltipRoundedRadius: 12,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.asMap().entries.map((entry) {
            final spot = entry.value;
            final isFirst = entry.key == 0;
            final idx = spot.x.toInt();
            final label = isFirst ? 'Sys' : 'Dia';
            final date = (idx < logs.length && isFirst)
                ? '\n${DateFormat('MMM d, y').format(logs[idx].timestamp)}'
                : '';
            return LineTooltipItem(
              '$label: ${spot.y.toStringAsFixed(0)}$date',
              TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isFirst ? 14 : 12,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return 10;
  }

  double _niceInterval(double range) {
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    return 25;
  }

  _TrendInfo _getTrend(List<VitalLog> logs, {bool isBP = false}) {
    final loc = context.read<LocalizationProvider>();
    if (logs.length < 2) {
      return _TrendInfo(loc.translate('stable'), Icons.trending_flat_rounded, AppColors.textMuted);
    }

    final recent = logs.last;
    final prev = logs[logs.length - 2];
    double recentVal, prevVal;

    if (isBP) {
      final rParts = recent.value.split('/');
      final pParts = prev.value.split('/');
      recentVal = double.tryParse(rParts.isNotEmpty ? rParts[0] : '') ?? 0;
      prevVal = double.tryParse(pParts.isNotEmpty ? pParts[0] : '') ?? 0;
    } else {
      recentVal = double.tryParse(recent.value) ?? 0;
      prevVal = double.tryParse(prev.value) ?? 0;
    }

    final diff = recentVal - prevVal;
    final pct = prevVal != 0 ? (diff / prevVal * 100).abs() : 0.0;
    final pctStr = pct.toStringAsFixed(1);

    if (diff > 0) {
      return _TrendInfo('+$pctStr%', Icons.trending_up_rounded, AppColors.danger);
    } else if (diff < 0) {
      return _TrendInfo('-$pctStr%', Icons.trending_down_rounded, AppColors.success);
    }
    return _TrendInfo('Stable', Icons.trending_flat_rounded, AppColors.textMuted);
  }
}

class _TrendInfo {
  final String label;
  final IconData icon;
  final Color color;
  _TrendInfo(this.label, this.icon, this.color);
}

// ═══════════════════════════════════════════════════════════════════
// Add Vital Modal
// ═══════════════════════════════════════════════════════════════════
class _AddVitalModal extends StatefulWidget {
  const _AddVitalModal();

  @override
  State<_AddVitalModal> createState() => _AddVitalModalState();
}

class _AddVitalModalState extends State<_AddVitalModal> {
  String _selectedType = 'bp';
  final _valueController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final val = _valueController.text.trim();
    if (val.isEmpty) return;

    // Validate BP format
    if (_selectedType == 'bp' && !val.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use format: 120/80'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final memberId = context.read<FamilyProvider>().activeMemberId;
    await context.read<VitalsProvider>().addVital(_selectedType, val, date: _selectedDate, memberId: memberId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Log Vital',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),

          // Type selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _vitalSelector('bp', 'BP', Icons.favorite_rounded),
              _vitalSelector('hr', 'Heart Rate', Icons.monitor_heart_rounded),
              _vitalSelector('weight', 'Weight', Icons.scale_rounded),
            ],
          ),
          const SizedBox(height: 20),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, MMM d, y').format(_selectedDate),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Value input
          TextFormField(
            controller: _valueController,
            keyboardType: _selectedType == 'bp' ? TextInputType.text : TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: _selectedType == 'bp' ? 'Reading (e.g. 120/80)' : 'Reading',
              suffixText: _selectedType == 'bp'
                  ? 'mmHg'
                  : (_selectedType == 'hr' ? 'BPM' : 'lbs'),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _save,
              child: const Text(
                'Save Vital',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalSelector(String type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
