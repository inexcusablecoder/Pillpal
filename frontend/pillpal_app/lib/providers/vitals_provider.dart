import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/vital_log.dart';
import '../services/storage_service.dart';

class VitalsProvider extends ChangeNotifier {
  List<VitalLog> _vitals = [];
  bool _isLoading = false;
  String? _currentMemberId;

  List<VitalLog> get vitals => _vitals;
  bool get isLoading => _isLoading;
  String? get currentMemberId => _currentMemberId;

  List<VitalLog> getLogsByType(String type) {
    final filtered = _vitals.where((v) => v.type == type).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  Future<void> fetchVitals({String? memberId}) async {
    _isLoading = true;
    _currentMemberId = memberId;
    notifyListeners();

    final storage = await StorageService.getInstance();
    final jsonList = storage.getVitals(memberId: memberId);
    _vitals = jsonList.map((j) => VitalLog.fromJson(j)).toList();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addVital(String type, String value, {DateTime? date, String? memberId}) async {
    final newLog = VitalLog(
      id: const Uuid().v4(),
      type: type,
      value: value,
      timestamp: date ?? DateTime.now(),
    );

    _vitals.add(newLog);
    await _persist(memberId: memberId);
  }

  Future<void> deleteVital(String id, {String? memberId}) async {
    _vitals.removeWhere((v) => v.id == id);
    await _persist(memberId: memberId);
  }

  Future<void> _persist({String? memberId}) async {
    final storage = await StorageService.getInstance();
    final jsonList = _vitals.map((v) => v.toJson()).toList();
    await storage.saveVitals(jsonList, memberId: memberId ?? _currentMemberId);
    notifyListeners();
  }
}
