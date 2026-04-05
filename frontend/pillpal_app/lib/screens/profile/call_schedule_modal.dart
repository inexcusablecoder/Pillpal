import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../utils/api_error_message.dart';
import '../../widgets/gradient_button.dart';

class CallScheduleModal extends StatefulWidget {
  final Map<String, dynamic>? editSchedule;

  const CallScheduleModal({super.key, this.editSchedule});

  @override
  State<CallScheduleModal> createState() => _CallScheduleModalState();
}

class _CallScheduleModalState extends State<CallScheduleModal> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  final _audioUrlController = TextEditingController();
  
  String _callType = 'audio'; // 'text' or 'audio'
  List<TimeOfDay> _selectedTimes = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _scheduleTimezone = 'Asia/Kolkata';
  bool _isLoading = false;
  bool _testBusy = false;
  List<dynamic> _history = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    if (widget.editSchedule != null) {
      _loadEditData();
    } else {
      _phoneController.text = '+91';
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate!.add(const Duration(days: 90));
      _loadLastPhone();
    }
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeviceTimezone());
  }

  Future<void> _loadDeviceTimezone() async {
    if (widget.editSchedule != null) return;
    try {
      final tz = await FlutterTimezone.getLocalTimezone();
      if (tz.isNotEmpty && mounted) {
        setState(() => _scheduleTimezone = tz);
      }
    } catch (e) {
      debugPrint('Timezone detection failed (using default): $e');
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final data = await ApiClient.instance.getCallHistory();
      setState(() => _history = data);
    } catch (e) {
      debugPrint('Error loading call history: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  void _loadEditData() {
    final s = widget.editSchedule!;
    _phoneController.text = s['phone'] ?? '';
    _messageController.text = s['message'] ?? '';
    _audioUrlController.text = s['audio_url'] ?? '';
    _callType = s['call_type'] ?? 'audio';
    
    final List<dynamic> timesList = s['times'] ?? [];
    for (var tStr in timesList) {
      final parts = tStr.split(':');
      if (parts.length == 2) {
        _selectedTimes.add(TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        ));
      }
    }
    
    _startDate = DateTime.tryParse(s['start_date'] ?? '');
    _endDate = DateTime.tryParse(s['end_date'] ?? '');
    final stz = s['schedule_timezone']?.toString();
    if (stz != null && stz.isNotEmpty) {
      _scheduleTimezone = stz;
    }
  }

  Future<void> _loadLastPhone() async {
    try {
      final lastPhone = await ApiClient.instance.getLastPhone();
      if (lastPhone.isNotEmpty && mounted) {
        setState(() => _phoneController.text = lastPhone);
      }
    } catch (e) {
      debugPrint('Error loading last phone: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    _audioUrlController.dispose();
    super.dispose();
  }

  static final Uri _twilioVerifiedCallerIds = Uri.parse(
    'https://console.twilio.com/us1/develop/phone-numbers/manage/verified',
  );

  bool _isTwilioTrialUnverifiedError(String? msg) {
    if (msg == null || msg.isEmpty) return false;
    final m = msg.toLowerCase();
    return m.contains('unverified') ||
        (m.contains('trial') && m.contains('verified'));
  }

  Future<void> _openTwilioVerifiedNumbers() async {
    try {
      final ok = await launchUrl(
        _twilioVerifiedCallerIds,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the link. In Twilio Console go to: Develop → Phone Numbers → Verified Caller IDs.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Twilio Console → Develop → Phone Numbers → Verified Caller IDs. Add the same +91… number you use here.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickTimes() async {
    if (_selectedTimes.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 times allowed')));
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null && mounted) {
      if (!_selectedTimes.contains(time)) {
        setState(() => _selectedTimes.add(time));
      }
    }
  }

  void _removeTime(int index) {
    setState(() => _selectedTimes.removeAt(index));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initialDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? initialDate,
      firstDate: initialDate.subtract(const Duration(days: 365)),
      lastDate: initialDate.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _showSetupStatus() async {
    try {
      final s = await ApiClient.instance.getCallReminderStatus();
      if (!mounted) return;
      final notes = (s['notes'] as List<dynamic>?)?.map((e) => e.toString()).join('\n') ?? '';
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Call reminder setup'),
          content: SingleChildScrollView(
            child: SelectableText(
              'Scheduler running: ${s['scheduler_running']}\n'
              'Twilio SID set: ${s['twilio_account_sid_set']}\n'
              'Twilio token set: ${s['twilio_auth_token_set']}\n'
              'From number set: ${s['twilio_from_number_set']}\n'
              'Profile phone saved: ${s['profile_phone_e164_set']}\n'
              'Your schedules: ${s['your_saved_schedules']}\n\n'
              '$notes',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _openTwilioVerifiedNumbers();
              },
              child: const Text('Verified Caller IDs'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e)), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _runTestCall() async {
    setState(() => _testBusy = true);
    try {
      final p = _phoneController.text.trim();
      await ApiClient.instance.testReminderCall(
        phone: p.isEmpty ? null : p,
        mode: _callType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test call requested. Check your phone and activity below.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadHistory();
      if (mounted && _history.isNotEmpty) {
        final first = _history.first;
        if (first is Map<String, dynamic> &&
            first['status'] == 'failed' &&
            _isTwilioTrialUnverifiedError(first['error_message']?.toString())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 10),
              backgroundColor: AppColors.warning,
              content: const Text(
                'Twilio rejected the call: this number is not verified on your trial account. '
                'Verify it in Twilio Console, then try again—or upgrade Twilio.',
              ),
              action: SnackBarAction(
                label: 'Open Twilio',
                textColor: Colors.white,
                onPressed: () {
                  _openTwilioVerifiedNumbers();
                },
              ),
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageFromDio(e)), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  Future<void> _saveSchedule() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number empty')));
      return;
    }
    if (_selectedTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one call time')));
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select dates')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final formattedTimes = _selectedTimes.map((t) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }).toList();

      final formatter = DateFormat('yyyy-MM-dd');
      
      final msg = _messageController.text.trim();
      final url = _audioUrlController.text.trim();

      if (widget.editSchedule != null) {
        final rawId = widget.editSchedule!['id'];
        final scheduleId = rawId is int ? rawId : int.parse(rawId.toString());
        await ApiClient.instance.updateCallSchedule(
          id: scheduleId,
          phone: _phoneController.text.trim(),
          times: formattedTimes,
          startDate: formatter.format(_startDate!),
          endDate: formatter.format(_endDate!),
          callType: _callType,
          message: msg.isNotEmpty ? msg : null,
          audioUrl: url.isNotEmpty ? url : null,
          scheduleTimezone: _scheduleTimezone,
        );
      } else {
        await ApiClient.instance.scheduleCall(
          phone: _phoneController.text.trim(),
          times: formattedTimes,
          startDate: formatter.format(_startDate!),
          endDate: formatter.format(_endDate!),
          callType: _callType,
          message: msg.isNotEmpty ? msg : null,
          audioUrl: url.isNotEmpty ? url : null,
          scheduleTimezone: _scheduleTimezone,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule saved!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save schedule.'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.editSchedule != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isEditing ? 'Edit Schedule' : 'Schedule Twilio Call',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: _testBusy ? null : _runTestCall,
                icon: _testBusy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.call_outlined, size: 18),
                label: const Text('Test call now'),
              ),
              TextButton.icon(
                onPressed: _showSetupStatus,
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Setup status'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Using ChoiceChip instead of SegmentedButton for broader compatibility
          const Text('Call Content', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Audio/MP3'),
                selected: _callType == 'audio',
                onSelected: (v) => setState(() => _callType = 'audio'),
                selectedColor: AppColors.primary.withAlpha(50),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Text Speech'),
                selected: _callType == 'text',
                onSelected: (v) => setState(() => _callType = 'text'),
                selectedColor: AppColors.primary.withAlpha(50),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Target Number', prefixIcon: Icon(Icons.phone), hintText: '+919876543210'),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'On a Twilio trial, your phone will not ring until this exact number is verified in Twilio '
                        '(Verified Caller IDs). Use E.164 format with country code, e.g. +919028767989—no spaces. '
                        'After Twilio confirms it, run Test call again. Paid Twilio accounts can call unverified numbers.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _openTwilioVerifiedNumbers,
                    child: const Text('Open Verified Caller IDs'),
                  ),
                ),
              ],
            ),
          ),

          if (_callType == 'text') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Voice Message (Text)', prefixIcon: Icon(Icons.message_rounded), hintText: 'Example: It is time for your Paracetamol.'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            TextField(
              controller: _audioUrlController,
              decoration: const InputDecoration(labelText: 'Custom Audio URL (Optional)', prefixIcon: Icon(Icons.link_rounded), hintText: 'Default music used if empty'),
            ),
          ],
          
          const SizedBox(height: 16),
          const Text('Call Times (Max 3)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'Uses timezone: $_scheduleTimezone (same as your device when you save).',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ..._selectedTimes.asMap().entries.map((e) => Chip(
                label: Text(e.value.format(context)),
                onDeleted: () => _removeTime(e.key),
              )),
              if (_selectedTimes.length < 3)
                ActionChip(label: const Text('+ Add Time'), onPressed: _pickTimes),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: InkWell(onTap: () => _pickDate(isStart: true), child: InputDecorator(decoration: const InputDecoration(labelText: 'Start Date'), child: Text(_startDate != null ? DateFormat('MMM d').format(_startDate!) : 'Select')))),
              const SizedBox(width: 12),
              Expanded(child: InkWell(onTap: () => _pickDate(isStart: false), child: InputDecorator(decoration: const InputDecoration(labelText: 'End Date'), child: Text(_endDate != null ? DateFormat('MMM d').format(_endDate!) : 'Select')))),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: GradientButton(text: isEditing ? 'Update Schedule' : 'Save Schedule', isLoading: _isLoading, onPressed: _saveSchedule)),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Recent Call Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (_isLoadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_history.isEmpty)
            const Text('No recent calls found.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          else
            ..._history.take(5).map((h) => _buildHistoryItem(h)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> h) {
    final bool isFailed = h['status'] == 'failed';
    final DateTime? ts = DateTime.tryParse(h['timestamp'] ?? '');
    final String timeStr = ts != null ? DateFormat('MMM d, HH:mm').format(ts) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isFailed ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: isFailed ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${h['call_type'] == 'text' ? "Voice Msg" : "Audio Call"} to ${h['phone']}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
                if (isFailed && h['error_message'] != null) ...[
                  Text(
                    h['error_message'] as String,
                    style: const TextStyle(fontSize: 11, color: AppColors.danger),
                  ),
                  if (_isTwilioTrialUnverifiedError(h['error_message']?.toString()))
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: _openTwilioVerifiedNumbers,
                      child: const Text(
                        'Fix: verify this number in Twilio (tap to open Console)',
                        style: TextStyle(fontSize: 11, decoration: TextDecoration.underline),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
