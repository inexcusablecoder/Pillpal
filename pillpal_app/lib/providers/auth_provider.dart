import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';

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

  Future<void> init() async {
    if (_isInitialized) return;
    _isLoading = true;
    notifyListeners();

    _user = User(id: "1", email: "demo@pillpal.com", displayName: "Demo User", createdAt: DateTime.now());
    
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
      _error = _extractError(e);
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
      _error = _extractError(e);
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
      _error = _extractError(e);
    } catch (e) {
      _error = 'Failed to update profile.';
    }

    _isLoading = false;
    notifyListeners();
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

  String _extractError(DioException e) {
    if (e.response?.data is Map) {
      final detail = (e.response!.data as Map)['detail'];
      if (detail is String) return detail;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Cannot connect to server. Check your internet or backend URL.';
    }
    return 'Something went wrong. Please try again.';
  }
}
