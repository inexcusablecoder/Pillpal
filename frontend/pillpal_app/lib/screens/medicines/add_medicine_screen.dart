import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/medicine.dart';
import '../../providers/medicine_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/gradient_button.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine; // null = add, non-null = edit

  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _pillCountController;
  late TextEditingController _thresholdController;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  bool _reminderEnabled = true;
  bool _isLoading = false;

  bool get isEditing => widget.medicine != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine?.name ?? '');
    _dosageController = TextEditingController(text: widget.medicine?.dosage ?? '');
    _pillCountController = TextEditingController(
      text: widget.medicine?.pillCount?.toString() ?? '',
    );
    _thresholdController = TextEditingController(text: '5');
    if (widget.medicine != null) {
      _selectedTime = widget.medicine!.scheduledTime;
      _reminderEnabled = widget.medicine!.reminderEnabled;
      StorageService.getInstance().then((storage) {
        final val = storage.getRefillThreshold(widget.medicine!.id);
        if (val != null) {
          _thresholdController.text = val.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _pillCountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _timeToApi(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.surface,
              dialBackgroundColor: AppColors.background,
              hourMinuteColor: AppColors.surfaceLight,
              dayPeriodColor: AppColors.surfaceLight,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final meds = context.read<MedicineProvider>();
    final pillCount = _pillCountController.text.trim().isNotEmpty
        ? int.tryParse(_pillCountController.text.trim())
        : null;
    final threshold = _thresholdController.text.trim().isNotEmpty
        ? int.tryParse(_thresholdController.text.trim()) ?? 5
        : 5;

    bool ok = false;
    String? medId;
    if (isEditing) {
      ok = await meds.updateMedicine(
        widget.medicine!.id,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        scheduledTime: _timeToApi(_selectedTime),
        reminderEnabled: _reminderEnabled,
        pillCount: pillCount,
      );
      if (ok) medId = widget.medicine!.id;
    } else {
      medId = await meds.addMedicine(
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        scheduledTime: _timeToApi(_selectedTime),
        reminderEnabled: _reminderEnabled,
        pillCount: pillCount,
      );
      ok = medId != null;
    }

    if (ok && medId != null) {
      final storage = await StorageService.getInstance();
      await storage.saveRefillThreshold(medId, threshold);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Medicine updated!' : 'Medicine added!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(meds.error ?? 'Something went wrong'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medicine icon header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 32),

              // Name
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  prefixIcon: Icon(Icons.medical_services_outlined, color: AppColors.textMuted),
                  hintText: 'e.g. Metformin',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // Dosage
              TextFormField(
                controller: _dosageController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  prefixIcon: Icon(Icons.science_outlined, color: AppColors.textMuted),
                  hintText: 'e.g. 500mg',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Dosage is required' : null,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // Time picker
              GestureDetector(
                onTap: _pickTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Scheduled Time',
                      prefixIcon: const Icon(Icons.schedule, color: AppColors.textMuted),
                      hintText: _formatTime(_selectedTime),
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                    ),
                    controller: TextEditingController(text: _formatTime(_selectedTime)),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // Pill count
              TextFormField(
                controller: _pillCountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Box Inventory (optional)',
                  prefixIcon: Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                  hintText: 'e.g. 30 pills in box',
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // Refill Threshold
              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Refill Warning Threshold',
                  prefixIcon: Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  hintText: 'e.g. 5 (Warn when 5 pills left)',
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Remind me at this time',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Alarm-style notification when Profile → Alarm reminders is on',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _reminderEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _reminderEnabled = v),
              ).animate().fadeIn(duration: 400.ms, delay: 480.ms).slideX(begin: 0.1),
              const SizedBox(height: 24),

              // Save button
              GradientButton(
                text: isEditing ? 'Update Medicine' : 'Add Medicine',
                isLoading: _isLoading,
                onPressed: _save,
                icon: isEditing ? Icons.save_rounded : Icons.add_rounded,
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}
