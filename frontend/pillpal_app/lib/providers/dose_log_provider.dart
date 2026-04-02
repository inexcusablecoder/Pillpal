import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/dose_log.dart';
import '../services/api_client.dart';
import '../utils/api_error_message.dart';

class DoseLogProvider extends ChangeNotifier {
  List<DoseLog> _todayLogs = [];
  List<DoseLog> _historyLogs = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;

  List<DoseLog> get todayLogs => _todayLogs;
  List<DoseLog> get historyLogs => _historyLogs;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  // Computed stats
  int get todayTotal => _todayLogs.length;
  int get todayTaken => _todayLogs.where((d) => d.isTaken).length;
  int get todayMissed => _todayLogs.where((d) => d.isMissed).length;
  int get todayPending => _todayLogs.where((d) => d.isPending).length;

  double get todayAdherence {
    if (todayTotal == 0) return 0;
    final completed = todayTaken + todayMissed;
    if (completed == 0) return 0;
    return todayTaken / completed * 100;
  }

  Future<void> syncAndFetchToday() async {
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.instance.syncDoseLogs();
      await fetchToday();
    } on DioException catch (e) {
      _error = messageFromDio(e);
    } catch (e) {
      _error = 'Failed to sync doses.';
    }

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> fetchToday() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.todayDoseLogs();
      _todayLogs = data
          .map((e) => DoseLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = messageFromDio(e);
    } catch (e) {
      _error = 'Failed to load today\'s doses.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchHistory({int days = 30}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.historyDoseLogs(days: days);
      _historyLogs = data
          .map((e) => DoseLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = messageFromDio(e);
    } catch (e) {
      _error = 'Failed to load history.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> takeDose(String logId) async {
    _error = null;

    try {
      final data = await ApiClient.instance.takeDose(logId);
      // Update the local list
      final idx = _todayLogs.indexWhere((d) => d.id == logId);
      if (idx != -1) {
        _todayLogs[idx] = DoseLog.fromJson(data);
        notifyListeners();
      }
      return true;
    } on DioException catch (e) {
      _error = messageFromDio(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to mark dose.';
      notifyListeners();
      return false;
    }
  }
}
