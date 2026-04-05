import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/common_medicines.dart';
import '../../config/theme.dart';
import '../../models/medicine.dart';
import '../../providers/medicine_provider.dart';
import '../../services/api_client.dart';
import '../../services/storage_service.dart';
import '../../widgets/authenticated_medicine_label_image.dart';
import '../../widgets/gradient_button.dart';
import '../../providers/localization_provider.dart';
import '../../utils/api_error_message.dart';

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
  bool _previewLoading = false;
  bool _labelBusy = false;
  Map<String, dynamic>? _previewFields;

  bool get isEditing => widget.medicine != null;

  Medicine? _editingMedicine(MedicineProvider meds) {
    if (!isEditing) return null;
    final id = widget.medicine!.id;
    for (final m in meds.medicines) {
      if (m.id == id) return m;
    }
    return widget.medicine;
  }

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

  Future<void> _pickAndPreviewLabel() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => _previewLoading = true);
    try {
      final bytes = await x.readAsBytes();
      final data = await ApiClient.instance.analyzeLabelPreview(bytes, x.name);
      if (!mounted) return;
      setState(() {
        _previewFields = data;
        _previewLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _previewLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDio(e)), backgroundColor: AppColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _applyPreviewToForm() {
    final p = _previewFields;
    if (p == null) return;
    final name = p['product_name']?.toString();
    final strength = p['strength']?.toString();
    if (name != null && name.isNotEmpty) {
      if (_catalogNames.contains(name)) {
        setState(() => _selectedMedicine = name);
      } else {
        setState(() {
          _selectedMedicine = CommonMedicines.otherValue;
          _otherNameController.text = name;
        });
      }
    }
    if (strength != null && strength.isNotEmpty) {
      _dosageController.text = strength;
    }
    setState(() {});
  }

  Future<void> _uploadLabelPhoto() async {
    if (!isEditing) return;
    final meds = context.read<MedicineProvider>();
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => _labelBusy = true);
    try {
      final bytes = await x.readAsBytes();
      await ApiClient.instance.uploadMedicineLabelImage(widget.medicine!.id, bytes, x.name);
      await meds.fetchMedicines();
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label photo saved'), backgroundColor: AppColors.success),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDio(e)), backgroundColor: AppColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _analyzeStoredLabel() async {
    if (!isEditing) return;
    final meds = context.read<MedicineProvider>();
    setState(() => _labelBusy = true);
    try {
      await ApiClient.instance.analyzeMedicineLabelStored(widget.medicine!.id);
      await meds.fetchMedicines();
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI summary updated'), backgroundColor: AppColors.success),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDio(e)), backgroundColor: AppColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _deleteLabelPhoto() async {
    if (!isEditing) return;
    final meds = context.read<MedicineProvider>();
    setState(() => _labelBusy = true);
    try {
      await ApiClient.instance.deleteMedicineLabelImage(widget.medicine!.id);
      await meds.fetchMedicines();
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label photo removed'), backgroundColor: AppColors.success),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDio(e)), backgroundColor: AppColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _labelBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
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

    final loc = context.read<LocalizationProvider>();
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
    final meds = context.watch<MedicineProvider>();
    final editMed = _editingMedicine(meds);
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

              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                'Label photo & AI',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEditing
                    ? 'Preview from any photo, or upload a label on this medicine and run full AI reading.'
                    : 'Pick a label photo to preview extracted text (save the medicine first to store the image).',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _previewLoading ? null : _pickAndPreviewLabel,
                icon: _previewLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(_previewLoading ? 'Reading…' : 'Read label with AI (preview)'),
              ),
              if (_previewFields != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _previewFields!['product_name']?.toString() ?? '—',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_previewFields!['strength'] ?? '—'} · ${_previewFields!['form'] ?? '—'}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                      if (_previewFields!['summary'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _previewFields!['summary'].toString(),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _applyPreviewToForm,
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Apply name & strength to form'),
                      ),
                    ],
                  ),
                ),
              ],
              if (isEditing) ...[
                const SizedBox(height: 16),
                if ((editMed?.labelImageKey ?? '').isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AuthenticatedMedicineLabelImage(
                        medicineId: widget.medicine!.id,
                        width: 168,
                        height: 168,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _labelBusy ? null : _uploadLabelPhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Upload label'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _labelBusy ? null : _analyzeStoredLabel,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI read saved photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _labelBusy ? null : _deleteLabelPhoto,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
                if (editMed != null && (editMed.labelAnalysisText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'AI label summary',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    editMed.labelAnalysisText!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                  ),
                ],
              ],
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
