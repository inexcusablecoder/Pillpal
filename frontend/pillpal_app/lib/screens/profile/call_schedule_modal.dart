import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.editSchedule != null) {
      _loadEditData();
    } else {
      _loadLastPhone();
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
        await ApiClient.instance.updateCallSchedule(
          id: widget.editSchedule!['id'],
          phone: _phoneController.text.trim(),
          times: formattedTimes,
          startDate: formatter.format(_startDate!),
          endDate: formatter.format(_endDate!),
          callType: _callType,
          message: msg.isNotEmpty ? msg : null,
          audioUrl: url.isNotEmpty ? url : null,
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
              Text(
                isEditing ? 'Edit Schedule' : 'Schedule Twilio Call',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          
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
          SizedBox(width: double.infinity, child: GradientButton(text: isEditing ? 'Update Schedule' : 'Save Schedule', isLoading: _isLoading, onPressed: _saveSchedule)),
        ],
      ),
    );
  }
}
