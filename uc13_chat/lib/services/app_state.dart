import 'package:flutter/foundation.dart';
import 'dart:typed_data';

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

  bool get initialDataLoaded => _initialDataLoaded;
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;

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
}