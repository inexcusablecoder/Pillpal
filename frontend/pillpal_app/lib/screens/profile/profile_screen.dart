import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/family_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/medicine_provider.dart';
import '../../services/web_reminder.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import 'add_family_member_modal.dart';
import 'call_schedule_modal.dart';
import '../../services/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _phoneFieldUserId;
  List<dynamic> _callSchedules = [];
  bool _isLoadingSchedules = false;

  @override
  void initState() {
    super.initState();
    _loadCallSchedules();
  }

  Future<void> _loadCallSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final data = await ApiClient.instance.getCallSchedules();
      setState(() => _callSchedules = data);
    } catch (e) {
      debugPrint('Error loading call schedules: $e');
    } finally {
      setState(() => _isLoadingSchedules = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncPhoneFieldForUser(String? userId, String? phoneE164) {
    if (userId == null) return;
    if (_phoneFieldUserId != userId) {
      _phoneFieldUserId = userId;
      _phoneController.text = phoneE164 ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final family = context.watch<FamilyProvider>();
    _syncPhoneFieldForUser(user?.id, user?.phoneE164);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    (user?.greeting ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 16),
              Text(
                user?.greeting ?? 'User',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              const SizedBox(height: 32),

              // User Info cards
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(Icons.email_outlined, 'Email', user?.email ?? ''),
                    const Divider(color: AppColors.cardBorder, height: 24),
                    _infoRow(
                      Icons.calendar_today_outlined,
                      'Member since',
                      user != null ? DateFormat('MMM d, yyyy').format(user.createdAt) : '',
                    ),
                    const Divider(color: AppColors.cardBorder, height: 24),
                    _editableName(auth),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Dose alarms (free: local notifications; phone stored for future paid calls)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alarm_rounded, color: AppColors.primary.withValues(alpha: 0.9)),
                        const SizedBox(width: 10),
                        const Text(
                          'Dose reminders',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Turn on for alarm-style alerts at each medicine’s scheduled time. '
                      'Real phone calls need a paid provider later — we store your number for that.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Alarm reminders',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        kIsWeb
                            ? 'Browser: allow notifications when prompted. Keep this tab open for alerts.'
                            : 'Requires notification + exact alarm permission on Android',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      value: user?.alarmRemindersEnabled ?? false,
                      activeThumbColor: AppColors.primary,
                      onChanged: auth.isLoading
                          ? null
                          : (v) async {
                              final ok = await auth.updateReminderSettings(
                                alarmRemindersEnabled: v,
                              );
                              if (ok && context.mounted) {
                                context.read<MedicineProvider>().setUserAlarmRemindersEnabled(v);
                                if (kIsWeb && v) {
                                  final granted =
                                      await requestBrowserNotificationPermission();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        granted
                                            ? 'Notifications allowed. Dose reminders fire while this tab stays open.'
                                            : 'Click the lock/info icon in the address bar and allow Notifications for localhost.',
                                      ),
                                      backgroundColor:
                                          granted ? AppColors.success : AppColors.warning,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  final granted =
                                      await requestBrowserNotificationPermission();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        granted
                                            ? 'Notifications are allowed for this site.'
                                            : 'Blocked or not supported. Use the site settings (lock icon) → Notifications → Allow.',
                                      ),
                                      backgroundColor:
                                          granted ? AppColors.success : AppColors.warning,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.notifications_active_outlined, size: 18),
                          label: const Text('Ask browser for notification permission'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Mobile (E.164, optional)',
                        hintText: '+919876543210',
                        prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                final ok = await auth.updateReminderSettings(
                                  phoneE164: _phoneController.text.trim(),
                                );
                                if (context.mounted && ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Phone number saved'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('Save phone'),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 350.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // ── PREMIUM PHONE CALLS ────────────────────
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_in_talk_rounded, color: AppColors.success.withAlpha(220)),
                        const SizedBox(width: 10),
                        const Text(
                          'Premium Call Reminders',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get an actual automated phone call (via Twilio) telling you to take your medications.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final refreshed = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const CallScheduleModal(),
                          );
                          if (refreshed == true) _loadCallSchedules();
                        },
                        icon: const Icon(Icons.settings_phone_rounded, size: 18),
                        label: const Text('Configure Calls'),
                      ),
                    ),
                    if (_callSchedules.isNotEmpty) ...[
                      const Divider(color: AppColors.cardBorder, height: 24),
                      const Text(
                        'Active Schedules',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ..._callSchedules.map((s) => _buildScheduleItem(s)),
                    ] else if (_isLoadingSchedules)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 380.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // ── MY FAMILY SECTION ──────────────────────
              _buildFamilySection(family),

              const SizedBox(height: 24),

              // App info card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(Icons.info_outline, 'Version', '1.0.0'),
                    const Divider(color: AppColors.cardBorder, height: 24),
                    _infoRow(Icons.code, 'Team', 'CodeConquerors'),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 32),

              // Logout
              GradientButton(
                text: 'Sign Out',
                icon: Icons.logout_rounded,
                onPressed: () => _confirmLogout(context, auth),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> s) {
    bool isText = s['call_type'] == 'text';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(
              isText ? Icons.record_voice_over_rounded : Icons.audiotrack_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['phone'] ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${isText ? "TTS" : "Audio"} | ${(s['times'] as List).join(", ")}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              onPressed: () async {
                final refreshed = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CallScheduleModal(editSchedule: s),
                );
                if (refreshed == true) _loadCallSchedules();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
              onPressed: () => _confirmDeleteSchedule(s['id']),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSchedule(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule?'),
        content: const Text('This will stop these automated calls immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiClient.instance.deleteCallSchedule(id);
              _loadCallSchedules();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Family Section ─────────────────────────────────
  Widget _buildFamilySection(FamilyProvider family) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.family_restroom_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Text(
              'My Family',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showAddMemberModal(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (family.members.length <= 1)
          GlassCard(
            padding: const EdgeInsets.all(20),
            onTap: () => _showAddMemberModal(),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add a family member',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track meds & vitals for your loved ones',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms)
        else
          ...family.members.where((m) => !m.isSelf).map((member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                onTap: () => _showMemberOptions(member),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: member.avatarColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: family.activeMemberId == member.id
                              ? member.avatarColor
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(member.avatarEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.relationship,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (family.activeMemberId == member.id)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
            );
          }),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }

  void _showAddMemberModal({FamilyMember? editMember}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFamilyMemberModal(editMember: editMember),
    );
  }

  void _showMemberOptions(FamilyMember member) {
    final familyProvider = context.read<FamilyProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: member.avatarColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(member.avatarEmoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              member.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              member.relationship,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            _optionTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Switch to ${member.name}',
              color: AppColors.primary,
              onTap: () {
                familyProvider.switchMember(member.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Now viewing ${member.name}\'s data'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
            _optionTile(
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: AppColors.textSecondary,
              onTap: () {
                Navigator.pop(ctx);
                _showAddMemberModal(editMember: member);
              },
            ),
            _optionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Remove',
              color: AppColors.danger,
              onTap: () {
                Navigator.pop(ctx);
                _confirmRemoveMember(member);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _confirmRemoveMember(FamilyMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: Text(
          'This will delete all of ${member.name}\'s medications, vitals, and history data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<FamilyProvider>().removeMember(member.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ── Existing Profile UI ────────────────────────────
  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editableName(AuthProvider auth) {
    if (_isEditing) {
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Display name',
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.success),
            onPressed: () async {
              await auth.updateProfile(_nameController.text.trim());
              setState(() => _isEditing = false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.danger),
            onPressed: () => setState(() => _isEditing = false),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Display Name', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(
                auth.user?.displayName ?? 'Not set',
                style: TextStyle(
                  fontSize: 15,
                  color: auth.user?.displayName != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: AppColors.textMuted, size: 18),
          onPressed: () {
            _nameController.text = auth.user?.displayName ?? '';
            setState(() => _isEditing = true);
          },
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              auth.logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
