import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'http://167.99.46.249:8000';

  Map<String, String> get _headers => AuthService().authHeaders;

  // ── Glucose ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGlucoseReport({String days = '7'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/glucose/report?days=$days'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    _handleUnauth(response);
    throw Exception('Failed to fetch glucose report (${response.statusCode})');
  }

  Future<Map<String, dynamic>> analyseUser({
    required String fullName,
    required int age,
    required int weight,
    required int basalUnit,
    required int height,
  }) async {
    final body = {
      'full_name': fullName,
      'age': age,
      'weight': weight,
      'basal_unit': basalUnit,
      'height': height,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/glucose/analyse'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to analyse user (${response.statusCode})');
  }

  // ── Bolus ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBolustiming({
    String mealType = 'medium_gi',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/bolus/timing?meal_type=$mealType'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get bolus timing (${response.statusCode})');
  }

  Future<Map<String, dynamic>> logBolus({
    required double units,
    String bolusType = 'manual',
    String? mealType,
    double? glucoseAtInjection,
    int? injectToMealMin,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'units': units,
      'bolus_type': bolusType,
      'meal_type': ?mealType,
      'glucose_at_injection': ?glucoseAtInjection,
      'inject_to_meal_min': ?injectToMealMin,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/bolus/'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log bolus: ${response.body}');
  }

  Future<List<dynamic>> getBolus({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/bolus/?limit=$limit'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to get bolus list (${response.statusCode})');
  }

  // ── Basal ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> logBasal({
    required double units,
    String? insulin,
    String? time,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'units': units,
      'insulin': ?insulin,
      'time': ?time,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/basal'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log basal: ${response.body}');
  }

  Future<List<dynamic>> getBasal({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/basal?limit=$limit'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to get basal list (${response.statusCode})');
  }

  // ── Hypo ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> logHypo({
    required double lowestValue,
    required DateTime startedAt,
    DateTime? endedAt,
    int? durationMin,
    String? treatedWith,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'lowest_value': lowestValue,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
      'duration_min': ?durationMin,
      if (treatedWith != null && treatedWith.isNotEmpty)
        'treated_with': treatedWith,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/hypo'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log hypo: ${response.body}');
  }

  Future<List<dynamic>> getHypos({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/hypo?limit=$limit'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to get hypos (${response.statusCode})');
  }

  // ── Meal ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> logMeal({
    required String mealType,
    required double carbs,
    String? description,
    double? glucoseBefore,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'meal_type': mealType,
      'carbs': carbs,
      if (description != null && description.isNotEmpty)
        'description': description,
      'glucose_before': ?glucoseBefore,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/meal/'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log meal: ${response.body}');
  }

  Future<List<dynamic>> getMealCorrelation() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/meal/correlation'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to get meal correlation (${response.statusCode})');
  }

  // ── Insights ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAiInsights({int days = 7}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/insights/analyse'),
      headers: _headers,
      body: json.encode({'days': days}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get AI insights (${response.statusCode})');
  }

  // ── Reports ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMonthlyReport({int days = 30}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/reports/monthly?days=$days'),
      headers: _headers,
      body: json.encode({}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get monthly report (${response.statusCode})');
  }

  String pdfDownloadUrl(String reportDate) =>
      '$baseUrl/api/v1/reports/download/$reportDate';

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _handleUnauth(http.Response response) {
    if (response.statusCode == 401) {
      AuthService().logout();
    }
  }
}
