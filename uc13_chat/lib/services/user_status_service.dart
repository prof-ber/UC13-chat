import 'package:http/http.dart' as http;
import 'dart:convert';
import '../components/chat_screen.dart' show SERVER_IP;

class UserStatusService {
  static String get baseUrl => 'http://$SERVER_IP:3000';

  static Future<Map<String, bool>> getBulkUserStatus(List<String> userIds) async {
    final url = '$baseUrl/api/bulk-user-status';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userIds': userIds}),
      );
      if (response.statusCode == 200) {
        return Map<String, bool>.from(json.decode(response.body));
      }
    } catch (e) {
      print('Error fetching bulk user status: $e');
    }
    return {};
  }

  // Mantenha o método existente para compatibilidade
  static Future<bool> getUserStatus(String userId) async {
    final url = '$baseUrl/api/user-status/$userId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isOnline'];
      }
    } catch (e) {
      print('Error fetching user status: $e');
    }
    return false;
  }
}