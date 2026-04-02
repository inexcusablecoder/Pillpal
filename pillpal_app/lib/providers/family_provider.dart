import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/family_member.dart';
import '../services/storage_service.dart';

class FamilyProvider extends ChangeNotifier {
  List<FamilyMember> _members = [];
  String _activeMemberId = '';
  bool _isLoading = false;

  List<FamilyMember> get members => _members;
  bool get isLoading => _isLoading;

  FamilyMember get activeMember {
    final match = _members.where((m) => m.id == _activeMemberId);
    if (match.isNotEmpty) return match.first;
    final selfMatch = _members.where((m) => m.isSelf);
    if (selfMatch.isNotEmpty) return selfMatch.first;
    return _members.isNotEmpty ? _members.first : _createDefaultSelf();
  }

  String get activeMemberId => _activeMemberId;
  bool get isViewingSelf => activeMember.isSelf;

  FamilyMember _createDefaultSelf() {
    return FamilyMember(
      id: 'self',
      name: 'Me',
      relationship: 'Self',
      avatarEmoji: '👤',
      avatarColorValue: FamilyMember.avatarColors[0],
      createdAt: DateTime.now(),
      isSelf: true,
    );
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final storage = await StorageService.getInstance();
    final jsonList = storage.getFamilyMembers();

    if (jsonList.isEmpty) {
      // First time — create the "Self" member
      final self = _createDefaultSelf();
      _members = [self];
      _activeMemberId = self.id;
      await _persist();
    } else {
      _members = jsonList.map((j) => FamilyMember.fromJson(j)).toList();
      _activeMemberId = storage.getActiveMemberId() ?? _members.first.id;
    }

    _isLoading = false;
    notifyListeners();
  }

  void switchMember(String memberId) {
    if (_activeMemberId == memberId) return;
    _activeMemberId = memberId;
    _saveActiveMemberId();
    notifyListeners();
  }

  Future<void> addMember({
    required String name,
    required String relationship,
    required String emoji,
    required int colorValue,
  }) async {
    final member = FamilyMember(
      id: const Uuid().v4(),
      name: name,
      relationship: relationship,
      avatarEmoji: emoji,
      avatarColorValue: colorValue,
      createdAt: DateTime.now(),
      isSelf: false,
    );

    _members.add(member);
    await _persist();
  }

  Future<void> updateMember(
    String id, {
    String? name,
    String? relationship,
    String? emoji,
    int? colorValue,
  }) async {
    final index = _members.indexWhere((m) => m.id == id);
    if (index == -1) return;

    _members[index] = _members[index].copyWith(
      name: name,
      relationship: relationship,
      avatarEmoji: emoji,
      avatarColorValue: colorValue,
    );
    await _persist();
  }

  Future<void> removeMember(String id) async {
    final member = _members.where((m) => m.id == id);
    if (member.isEmpty || member.first.isSelf) return; // Can't remove self

    _members.removeWhere((m) => m.id == id);

    // If removed the active member, switch to self
    if (_activeMemberId == id) {
      _activeMemberId = _members.firstWhere((m) => m.isSelf).id;
    }

    // Clean up member's data
    final storage = await StorageService.getInstance();
    await storage.clearMemberData(id);

    await _persist();
  }

  Future<void> _persist() async {
    final storage = await StorageService.getInstance();
    final jsonList = _members.map((m) => m.toJson()).toList();
    await storage.saveFamilyMembers(jsonList);
    await _saveActiveMemberId();
    notifyListeners();
  }

  Future<void> _saveActiveMemberId() async {
    final storage = await StorageService.getInstance();
    await storage.saveActiveMemberId(_activeMemberId);
  }
}
