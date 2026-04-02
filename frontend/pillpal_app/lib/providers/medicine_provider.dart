import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/web_reminder.dart';
import '../utils/api_error_message.dart';

class MedicineProvider extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;
  String? _error;
  /// Master switch from GET /users/me — must be on for any dose alarm.
  bool _userAlarmRemindersEnabled = false;

  List<Medicine> get medicines => _medicines;
  List<Medicine> get activeMedicines => _medicines.where((m) => m.active).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get userAlarmRemindersEnabled => _userAlarmRemindersEnabled;

  void setUserAlarmRemindersEnabled(bool enabled) {
    if (_userAlarmRemindersEnabled == enabled) return;
    _userAlarmRemindersEnabled = enabled;
    _applyAllNotificationSchedules();
  }

  Future<void> _applyAllNotificationSchedules() async {
    for (final m in _medicines) {
      await _scheduleMedicineIfNeeded(m);
    }
  }

  Future<void> _scheduleMedicineIfNeeded(Medicine m) async {
    cancelWebReminder(m.id);
    if (!kIsWeb) {
      await NotificationService.instance.cancelReminder(m.id);
    }

    if (!m.active || !_userAlarmRemindersEnabled || !m.reminderEnabled) {
      return;
    }

    if (kIsWeb) {
      scheduleWebReminder(
        medicineId: m.id,
        medicineName: m.name,
        dosage: m.dosage,
        hour: m.scheduledTime.hour,
        minute: m.scheduledTime.minute,
      );
      return;
    }

    await NotificationService.instance.scheduleDailyMedicineReminder(
      medicineId: m.id,
      medicineName: m.name,
      dosage: m.dosage,
      hour: m.scheduledTime.hour,
      minute: m.scheduledTime.minute,
    );
  }

  Future<void> fetchMedicines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.listMedicines();
      _medicines = data
          .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
          .toList();
      await _applyAllNotificationSchedules();
    } on DioException catch (e) {
      _error = messageFromDio(e);
    } catch (e) {
      _error = 'Failed to load medicines.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> addMedicine({
    required String name,
    required String dosage,
    required String scheduledTime,
    String frequency = 'daily',
    bool reminderEnabled = true,
    int? pillCount,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.instance.createMedicine(
        name: name,
        dosage: dosage,
        scheduledTime: scheduledTime,
        frequency: frequency,
        reminderEnabled: reminderEnabled,
        pillCount: pillCount,
      );
      await fetchMedicines();

      final match = _medicines.where((med) => med.name == name).toList();
      return match.isNotEmpty ? match.first.id : null;
    } on DioException catch (e) {
      _error = messageFromDio(e);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to add medicine.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateMedicine(
    String id, {
    String? name,
    String? dosage,
    String? scheduledTime,
    bool? active,
    bool? reminderEnabled,
    int? pillCount,
  }) async {
    _error = null;

    try {
      await ApiClient.instance.updateMedicine(
        id,
        name: name,
        dosage: dosage,
        scheduledTime: scheduledTime,
        active: active,
        reminderEnabled: reminderEnabled,
        pillCount: pillCount,
      );
      await fetchMedicines();
      return true;
    } on DioException catch (e) {
      _error = messageFromDio(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to update medicine.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMedicine(String id) async {
    _error = null;

    try {
      await ApiClient.instance.deleteMedicine(id);
      _medicines.removeWhere((m) => m.id == id);
      cancelWebReminder(id);
      await NotificationService.instance.cancelReminder(id);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = messageFromDio(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to delete medicine.';
      notifyListeners();
      return false;
    }
  }
}
