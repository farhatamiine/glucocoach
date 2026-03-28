import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _baseUrl = 'http://167.99.46.249:8000';
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null;

  String get userName => _user?['full_name'] ?? _user?['name'] ?? 'User';
  String get userEmail => _user?['email'] ?? '';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = json.decode(userJson) as Map<String, dynamic>;
    }
  }

  Future<void> login({required String email, required String password}) async {
    // OAuth2 password flow — form-encoded
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body:
          'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      _token = data['access_token'] as String?;
      await _persistToken();
      await fetchMe();
    } else {
      final body = json.decode(response.body);
      throw Exception(body['detail'] ?? 'Login failed');
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String glucoseUnit = 'mg/dL',
    double? height,
    double? weight,
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName,
      'email': email,
      'password': password,
      'glucose_unit': glucoseUnit,
      'height': ?height,
      'weight': ?weight,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      // Auto-login after register
      await login(email: email, password: password);
    } else {
      final b = json.decode(response.body);
      throw Exception(b['detail'] ?? 'Registration failed');
    }
  }

  Future<void> fetchMe() async {
    if (_token == null) return;
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/auth/me'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      _user = json.decode(response.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json.encode(_user));
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> _persistToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_tokenKey, _token!);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };
}
