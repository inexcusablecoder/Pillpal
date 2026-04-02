import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

class MedicineProvider extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;
  String? _error;

  List<Medicine> get medicines => _medicines;
  List<Medicine> get activeMedicines => _medicines.where((m) => m.active).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMedicines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.listMedicines();
      _medicines = data
          .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = _extractError(e);
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
        pillCount: pillCount,
      );
      await fetchMedicines();

      // Schedule Native Alert
      final parts = scheduledTime.split(':');
      String? returnedId;
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 8;
        final m = int.tryParse(parts[1]) ?? 0;
        
        // Retrieve the newly synced medicine ID
        final meds = _medicines.where((med) => med.name == name).toList();
        if (meds.isNotEmpty) {
          returnedId = meds.first.id;
          await NotificationService.instance.scheduleDailyMedicineReminder(
            medicineId: meds.first.id,
            medicineName: name,
            dosage: dosage,
            hour: h,
            minute: m,
          );
        }
      }

      return returnedId ?? _medicines.firstWhere((m) => m.name == name).id;
    } on DioException catch (e) {
      _error = _extractError(e);
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
        pillCount: pillCount,
      );
      await fetchMedicines();

      if (scheduledTime != null || name != null || dosage != null || active != null) {
        // Just cancel and let them add a new one if it becomes complex 
        // to retrieve all unchanged properties for rescheduling.
        await NotificationService.instance.cancelReminder(id);
        
        final med = _medicines.firstWhere((m) => m.id == id);
        if (med.active) {
            final h = med.scheduledTime.hour;
            final m = med.scheduledTime.minute;
            await NotificationService.instance.scheduleDailyMedicineReminder(
              medicineId: med.id,
              medicineName: med.name,
              dosage: med.dosage,
              hour: h,
              minute: m,
            );
        }
      }

      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
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
      
      // Stop native alerts immediately
      await NotificationService.instance.cancelReminder(id);
      
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _extractError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to delete medicine.';
      notifyListeners();
      return false;
    }
  }

  String _extractError(DioException e) {
    if (e.response?.data is Map) {
      final detail = (e.response!.data as Map)['detail'];
      if (detail is String) return detail;
    }
    return 'Something went wrong.';
  }
}
