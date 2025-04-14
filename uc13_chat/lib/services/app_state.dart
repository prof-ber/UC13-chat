import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'user_status_service.dart';

class AppState with ChangeNotifier {
  static final AppState _instance = AppState._internal();

  factory AppState() {
    return _instance;
  }

  AppState._internal();

  bool _initialDataLoaded = false;
  bool _isLoggedIn = false;
  String? _userId;
  Map<String, Uint8List> _profilePictureCache = {};
  Map<String, bool> _userStatuses = {};
  String _connectionStatus = 'Disconnected';

  bool get initialDataLoaded => _initialDataLoaded;
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String get connectionStatus => _connectionStatus;

  void setConnectionStatus(String status) {
    _connectionStatus = status;
    notifyListeners();
  }

  void setInitialDataLoaded(bool value) {
    _initialDataLoaded = value;
    notifyListeners();
  }

  void setLoggedIn(bool value, String? newUserId) {
    _isLoggedIn = value;
    _userId = newUserId;
    notifyListeners();
  }

  Uint8List? getProfilePicture(String userId) {
    return _profilePictureCache[userId];
  }

  void setProfilePicture(String userId, Uint8List imageData) {
    _profilePictureCache[userId] = imageData;
    notifyListeners();
  }

  void clearCache() {
    _profilePictureCache.clear();
    notifyListeners();
  }

  // Métodos para gerenciar o status do usuário
  bool isUserOnline(String userId) {
    return _userStatuses[userId] ?? false;
  }

  Future<void> updateUserStatus(String userId) async {
    final isOnline = await UserStatusService.getUserStatus(userId);
    setUserStatus(userId, isOnline);
  }

  void setUserStatus(String userId, bool isOnline) {
    _userStatuses[userId] = isOnline;
    notifyListeners();
  }
}