import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'http://172.17.9.220:3000/api'; // Substitua pelo IP do seu servidor

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final headers = await getHeaders();
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Adicione este método à classe ApiService em api_service.dart
  Future<http.Response> multipartRequest(
    String method,
    String endpoint, {
    List<http.MultipartFile>? files,
  }) async {
    final headers = await getHeaders();
    var request = http.MultipartRequest(method, Uri.parse('$baseUrl$endpoint'));
    request.headers.addAll(headers);
    if (files != null) {
      request.files.addAll(files);
    }
  
    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: json.encode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to post data');
    }
  }

  // Você pode adicionar mais métodos aqui para outros tipos de requisições (PUT, DELETE, etc.)
}