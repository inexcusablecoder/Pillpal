import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dose_log_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/medicine_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/dose_card.dart';
import '../../widgets/glass_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _actioningId;
  late Future<StorageService> _storageFuture;

  @override
  void initState() {
    super.initState();
    _storageFuture = StorageService.getInstance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoseLogProvider>().syncAndFetchToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final doses = context.watch<DoseLogProvider>();
    final family = context.watch<FamilyProvider>();
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => doses.syncAndFetchToday(),
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.greeting ?? 'Friend',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(now),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                ],
              ),
            ),
          ),

          // ── Family Member Switcher ─────────────────────
          if (family.members.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildMemberSwitcher(family),
              ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
            ),

          // ── "Viewing X's data" banner ──────────────────
          if (!family.isViewingSelf && family.members.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: family.activeMember.avatarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: family.activeMember.avatarColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        family.activeMember.avatarEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Viewing ${family.activeMember.name}\'s data',
                          style: TextStyle(
                            color: family.activeMember.avatarColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final selfMember = family.members.firstWhere((m) => m.isSelf);
                          family.switchMember(selfMember.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Back to me',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),
              ),
            ),

          // ── Caregiver Alerts ───────────────────────────
          SliverToBoxAdapter(
            child: _buildCaregiverAlerts(family),
          ),

          // Stats cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _buildStatsRow(doses).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2),
            ),
          ),

          // Refill warnings
          SliverToBoxAdapter(
            child: FutureBuilder<StorageService>(
              future: _storageFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final meds = context.watch<MedicineProvider>().medicines;
                final storage = snapshot.data!;
                
                List<Widget> warnings = [];
                for (var med in meds) {
                  if (med.pillCount != null) {
                    final threshold = storage.getRefillThreshold(med.id) ?? 5;
                    if (med.pillCount! <= threshold) {
                      warnings.add(
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Low Stock: You only have ${med.pillCount} pills of ${med.name} left!',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: -0.2),
                      );
                    }
                  }
                }

                if (warnings.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(children: warnings),
                );
              },
            ),
          ),

          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (doses.isSyncing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
            ),
          ),

          // Dose list
          if (doses.isLoading && doses.todayLogs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (doses.todayLogs.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState().animate().fadeIn(duration: 500.ms, delay: 500.ms),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dose = doses.todayLogs[index];
                    return DoseCard(
                      dose: dose,
                      isActioning: _actioningId == dose.id,
                      onTake: () => _takeDose(dose.id),
                    ).animate(delay: Duration(milliseconds: 400 + index * 60)).fadeIn().slideX(begin: 0.1);
                  },
                  childCount: doses.todayLogs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Member Switcher ────────────────────────────────
  Widget _buildMemberSwitcher(FamilyProvider family) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: family.members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final member = family.members[index];
          final isActive = family.activeMemberId == member.id;

          return GestureDetector(
            onTap: () => family.switchMember(member.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? member.avatarColor.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? member.avatarColor : AppColors.cardBorder,
                  width: isActive ? 2 : 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: member.avatarColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: member.avatarColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        member.avatarEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.isSelf ? 'Me' : member.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isActive ? member.avatarColor : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        member.relationship,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Caregiver Alerts ──────────────────────────────
  Widget _buildCaregiverAlerts(FamilyProvider family) {
    // Only show alerts when viewing own profile, for OTHER family members
    if (!family.isViewingSelf || family.members.length <= 1) {
      return const SizedBox.shrink();
    }

    final otherMembers = family.members.where((m) => !m.isSelf).toList();
    if (otherMembers.isEmpty) return const SizedBox.shrink();

    // Simulate missed dose alerts for demo (in production, this would check real dose logs per member)
    // For now, show a static helpful reminder
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: otherMembers.map((member) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: member.avatarColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: member.avatarColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: member.avatarColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(member.avatarEmoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${member.name}\'s health',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        'Tap to check their vitals & medications',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    family.switchMember(member.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: member.avatarColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: member.avatarColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.05);
        }).toList(),
      ),
    );
  }

  Widget _buildStatsRow(DoseLogProvider doses) {
    return Row(
      children: [
        Expanded(child: _statCard('Total', '${doses.todayTotal}', Icons.list_alt_rounded, AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Taken', '${doses.todayTaken}', Icons.check_circle_rounded, AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Pending', '${doses.todayPending}', Icons.schedule_rounded, AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Missed', '${doses.todayMissed}', Icons.cancel_rounded, AppColors.danger)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medication_liquid_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No doses scheduled for today',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a medicine to get started!',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _takeDose(String logId) async {
    setState(() => _actioningId = logId);
    
    final doseProvider = context.read<DoseLogProvider>();
    final medProvider = context.read<MedicineProvider>();
    final doseList = doseProvider.todayLogs.where((d) => d.id == logId);
    String? medId = doseList.isNotEmpty ? doseList.first.medicineId : null;

    final ok = await doseProvider.takeDose(logId);
    
    if (ok && medId != null) {
      final medList = medProvider.medicines.where((m) => m.id == medId);
      if (medList.isNotEmpty) {
        final med = medList.first;
        if (med.pillCount != null && med.pillCount! > 0) {
          await medProvider.updateMedicine(med.id, pillCount: med.pillCount! - 1);
        }
      }
    }

    if (mounted) {
      setState(() => _actioningId = null);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💊 Dose marked as taken!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}
