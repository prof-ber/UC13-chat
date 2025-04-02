import 'package:shared_preferences/shared_preferences.dart';
import '../components/contacts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String SERVER_IP = '172.17.9.224';

class AuthService {
  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName');
    final userAvatar = prefs.getString('userAvatar');
    final token = prefs.getString('token');

    print(
      "SharedPreferences data: userId=$userId, userName=$userName, userAvatar=$userAvatar, token=$token",
    );

    if (userId != null && token != null) {
      // If we have a userId and token, we consider the user logged in
      // If userName is null, we'll use the userId as a fallback
      return User(id: userId, name: userName ?? userId, avatarUrl: userAvatar);
    }
    return null;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');

    if (refreshToken == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('http://$SERVER_IP:3000/api/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await setAuthToken(data['token']);
        await prefs.setString('refreshToken', data['refreshToken']);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<void> setUserData(
    String id,
    String name,
    String? avatarUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', id);
    await prefs.setString('userName', name); // This line saves the username
    if (avatarUrl != null) {
      await prefs.setString('userAvatar', avatarUrl);
    }
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userAvatar');
    await clearAuthToken();
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://$SERVER_IP:3000/api/login'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{'nome': username, 'senha': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        String userId = data['usuario']['id'];
        String receivedToken = data['token'];
        String? avatarUrl = data['usuario']['avatarUrl'];

        await setUserData(userId, username, avatarUrl);
        await setAuthToken(receivedToken);
        if (data['refreshToken'] != null) {
          await _setRefreshToken(data['refreshToken']);
        }
        return {'success': true, 'userId': userId};
      } else {
        return {
          'success': false,
          'error': 'Login failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error during login: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('Logout successful');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  static Future<void> _setRefreshToken(String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refreshToken', refreshToken);
  }
}
