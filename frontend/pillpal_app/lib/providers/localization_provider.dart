import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/translations.dart';

class LocalizationProvider extends ChangeNotifier {
  String _currentLanguage = 'en';
  bool _isInitialized = false;

  String get currentLanguage => _currentLanguage;
  bool get isInitialized => _isInitialized;

  // Helper method for shorthand access
  String translate(String key) {
    return Translations.get(key, _currentLanguage);
  }

  Future<void> init() async {
    final storage = await StorageService.getInstance();
    final savedLang = storage.getLanguage();
    if (savedLang != null) {
      _currentLanguage = savedLang;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    
    _currentLanguage = lang;
    notifyListeners();

    // Save to local storage
    final storage = await StorageService.getInstance();
    await storage.saveLanguage(lang);

    // Save to database (backend)
    try {
      await ApiClient.instance.updateMe(language: lang);
    } catch (e) {
      debugPrint('Failed to save language to backend: $e');
    }
  }

  // Support for 7 Indian languages plus English
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'Hindi (हिन्दी)'},
    {'code': 'bn', 'name': 'Bengali (বাংলা)'},
    {'code': 'te', 'name': 'Telugu (తెలుగు)'},
    {'code': 'mr', 'name': 'Marathi (मराठी)'},
    {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
    {'code': 'gu', 'name': 'Gujarati (ગુજરાતી)'},
    {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
  ];
}
