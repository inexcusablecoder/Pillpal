import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _pillCountCtrl = TextEditingController(text: '30');
  final _refillAtCtrl = TextEditingController(text: '5');
  final _api = ApiService();
  final _notifService = NotificationService();

  TimeOfDay _selectedTime = TimeOfDay.now();
  String _frequency = 'daily';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _pillCountCtrl.dispose();
    _refillAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _timeString {
    final h = _selectedTime.hour.toString().padLeft(2, '0');
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final name = _nameCtrl.text.trim();
      final dosage = _dosageCtrl.text.trim();
      final medicineId = await _api.createMedicine(
        name: name,
        dosage: dosage,
        scheduledTime: _timeString,
        frequency: _frequency,
        pillCount: int.tryParse(_pillCountCtrl.text) ?? 30,
        refillAt: int.tryParse(_refillAtCtrl.text) ?? 5,
      );

      await _notifService.scheduleMedicineReminder(
        medicineId: medicineId,
        medicineName: name,
        dosage: dosage,
        scheduledTime: _timeString,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Medicine added successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add medicine: $e'),
              backgroundColor: AppTheme.missed),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medicine')),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medicine Name
                _SectionLabel('Medicine Name'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Metformin',
                    prefixIcon: Icon(Icons.medication_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter medicine name' : null,
                ),
                const SizedBox(height: 16),

                // Dosage
                _SectionLabel('Dosage'),
                TextFormField(
                  controller: _dosageCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 500mg or 1 tablet',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter dosage' : null,
                ),
                const SizedBox(height: 16),

                // Time Picker
                _SectionLabel('Reminder Time'),
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(
                              fontSize: 16, color: AppTheme.textPrimary),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Frequency
                _SectionLabel('Frequency'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _frequency,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Weekly')),
                      ],
                      onChanged: (v) =>
                          setState(() => _frequency = v ?? 'daily'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pill Count Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Total Pills'),
                          TextFormField(
                            controller: _pillCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                hintText: '30'),
                            validator: (v) =>
                                int.tryParse(v ?? '') == null
                                    ? 'Enter a number'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Refill Alert At'),
                          TextFormField(
                            controller: _refillAtCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                hintText: '5'),
                            validator: (v) =>
                                int.tryParse(v ?? '') == null
                                    ? 'Enter a number'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary))
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Medicine'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textSecondary)),
    );
  }
}
