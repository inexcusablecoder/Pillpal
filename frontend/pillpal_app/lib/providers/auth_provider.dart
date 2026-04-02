import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/api_error_message.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  /// Restore session from stored JWT, or stay logged out if missing / invalid.
  Future<void> init() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    try {
      final storage = await StorageService.getInstance();
      final token = storage.getToken();
      if (token == null || token.isEmpty) {
        _user = null;
      } else {
        final userData = await ApiClient.instance.getMe();
        _user = User.fromJson(userData);
        await storage.saveUserJson(userData);
      }
    } on DioException {
      _user = null;
      final storage = await StorageService.getInstance();
      await storage.clearAuth();
    } catch (_) {
      _user = null;
      final storage = await StorageService.getInstance();
      await storage.clearAuth();
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokenData = await ApiClient.instance.login(
        email: email,
        password: password,
      );
      final storage = await StorageService.getInstance();
      await storage.saveToken(tokenData['access_token'] as String);

      final userData = await ApiClient.instance.getMe();
      _user = User.fromJson(userData);
      await storage.saveUserJson(userData);

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = messageFromDio(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String? displayName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.instance.register(
        email: email,
        password: password,
        displayName: displayName,
      );

      // Auto-login after register
      return await login(email, password);
    } on DioException catch (e) {
      _error = messageFromDio(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(String displayName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.updateMe(displayName: displayName);
      _user = User.fromJson(data);
      final storage = await StorageService.getInstance();
      await storage.saveUserJson(data);
    } on DioException catch (e) {
      _error = messageFromDio(e);
    } catch (e) {
      _error = 'Failed to update profile.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Alarm-style dose reminders (local notifications). Phone number stored for a future paid call provider.
  Future<bool> updateReminderSettings({
    bool? alarmRemindersEnabled,
    String? phoneE164,
    bool clearPhone = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.updateMe(
        alarmRemindersEnabled: alarmRemindersEnabled,
        phoneE164: phoneE164,
        clearPhone: clearPhone,
      );
      _user = User.fromJson(data);
      final storage = await StorageService.getInstance();
      await storage.saveUserJson(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = messageFromDio(e);
    } catch (e) {
      _error = 'Failed to update reminder settings.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final storage = await StorageService.getInstance();
    await storage.clearAll();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
