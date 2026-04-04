import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../config/common_medicines.dart';
import '../../config/theme.dart';
import '../../models/medicine.dart';
import '../../providers/medicine_provider.dart';
import '../../services/api_client.dart';
import '../../services/storage_service.dart';
import '../../widgets/gradient_button.dart';
import '../../providers/localization_provider.dart';
import '../../utils/translations.dart';

class AddMedicineScreen extends StatefulWidget {
  final Medicine? medicine; // null = add, non-null = edit

  const AddMedicineScreen({super.key, this.medicine});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMedicine; // null = not chosen; [CommonMedicines.otherValue] = custom
  List<String> _catalogNames = List<String>.from(CommonMedicines.names);
  bool _catalogLoading = true;
  late TextEditingController _otherNameController;
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
    _otherNameController = TextEditingController();
    final existingName = widget.medicine?.name ?? '';
    if (existingName.isNotEmpty) {
      if (CommonMedicines.isListed(existingName)) {
        _selectedMedicine = existingName;
      } else {
        _selectedMedicine = CommonMedicines.otherValue;
        _otherNameController.text = existingName;
      }
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMedicineCatalog());
  }

  void _reconcileSelectionWithCatalog() {
    final med = widget.medicine;
    if (med == null) return;
    final n = med.name;
    if (_catalogNames.contains(n)) {
      _selectedMedicine = n;
    } else {
      _selectedMedicine = CommonMedicines.otherValue;
      _otherNameController.text = n;
    }
  }

  Future<void> _loadMedicineCatalog() async {
    final storage = await StorageService.getInstance();
    final cached = storage.getMedicineCatalogNames();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _catalogNames = cached;
        _reconcileSelectionWithCatalog();
      });
    }
    try {
      final raw = await ApiClient.instance.getMedicineCatalog();
      final names = raw
          .map((e) => (e as Map<String, dynamic>)['name'] as String)
          .toList();
      await storage.saveMedicineCatalogNames(names);
      if (!mounted) return;
      setState(() {
        _catalogNames = names;
        _catalogLoading = false;
        _reconcileSelectionWithCatalog();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _catalogLoading = false;
          if (_catalogNames.isEmpty) {
            _catalogNames = List<String>.from(CommonMedicines.names);
          }
          _reconcileSelectionWithCatalog();
        });
      }
    }
  }

  @override
  void dispose() {
    _otherNameController.dispose();
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

  String? _resolvedMedicineName() {
    if (_selectedMedicine == null) return null;
    if (_selectedMedicine == CommonMedicines.otherValue) {
      return _otherNameController.text.trim();
    }
    return _selectedMedicine;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final meds = context.read<MedicineProvider>();
    final name = _resolvedMedicineName();
    if (name == null || name.isEmpty) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('select_med_error')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

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
        name: name,
        dosage: _dosageController.text.trim(),
        scheduledTime: _timeToApi(_selectedTime),
        reminderEnabled: _reminderEnabled,
        pillCount: pillCount,
      );
      if (ok) medId = widget.medicine!.id;
    } else {
      medId = await meds.addMedicine(
        name: name,
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
            content: Text(isEditing ? loc.translate('med_updated') : loc.translate('med_added')),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(meds.error ?? loc.translate('wrong_error')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? loc.translate('edit_med_title') : loc.translate('add_med_title')),
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
              if (_catalogLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceLight,
                  ),
                ),

              // Medicine (dropdown from API/DB + cache; fallback: bundled list)
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: _selectedMedicine,
                isExpanded: true,
                isDense: false,
                menuMaxHeight: 360,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  labelText: loc.translate('nav_meds'),
                  prefixIcon: const Icon(Icons.medical_services_outlined, color: AppColors.textMuted),
                  hintText: loc.translate('choose_from_list'),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      '— ${loc.translate('select_medicine')} —',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  ..._catalogNames.map(
                    (n) => DropdownMenuItem<String?>(
                      value: n,
                      child: Text(n, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DropdownMenuItem<String?>(
                    value: CommonMedicines.otherValue,
                    child: Text(loc.translate('other_type_name')),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedMedicine = v),
                validator: (v) => v == null ? loc.translate('select_medicine') : null,
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1),
              if (_selectedMedicine == CommonMedicines.otherValue) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otherNameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: loc.translate('custom_med_name'),
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.textMuted),
                    hintText: loc.translate('eg_brand'),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? loc.translate('enter_med_name_error') : null,
                ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
              ],
              const SizedBox(height: 16),

              // Dosage
              TextFormField(
                controller: _dosageController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: loc.translate('dosage'),
                  prefixIcon: const Icon(Icons.science_outlined, color: AppColors.textMuted),
                  hintText: loc.translate('eg_dosage'),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? loc.translate('dosage_error') : null,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // Time picker
              GestureDetector(
                onTap: _pickTime,
                child: AbsorbPointer(
                  child: TextFormField(
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: loc.translate('scheduled_time'),
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
                decoration: InputDecoration(
                  labelText: loc.translate('inventory_label'),
                  prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                  hintText: loc.translate('inventory_hint'),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),

              // Refill Threshold
              TextFormField(
                controller: _thresholdController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: loc.translate('refill_threshold'),
                  prefixIcon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  hintText: loc.translate('threshold_hint'),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideX(begin: 0.1),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  loc.translate('remind_me_at_time'),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  loc.translate('reminder_subtitle'),
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                value: _reminderEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _reminderEnabled = v),
              ).animate().fadeIn(duration: 400.ms, delay: 480.ms).slideX(begin: 0.1),
              const SizedBox(height: 24),

              // Save button
              GradientButton(
                text: isEditing ? loc.translate('edit_med_title') : loc.translate('add_med_title'),
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
