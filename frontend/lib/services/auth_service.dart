import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String _backendUrl;
  final http.Client _client;
  String? _token;

  AuthService()
      : _backendUrl = const String.fromEnvironment('BACKEND_HTTP', defaultValue: 'http://localhost:8080'),
        _client = kIsWeb ? (BrowserClient()..withCredentials = true) : http.Client() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
    } catch (e) {
      debugPrint('Error loading token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<void> _clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      debugPrint('Error clearing token: $e');
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Get current user session
  Future<Map<String, dynamic>?> getSession() async {
    try {
      final response = await _client.get(
        Uri.parse('$_backendUrl/api/auth/get-session'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['session'] != null) {
          final sessionToken = data['session']['token'];
          if (sessionToken != null) {
            await _saveToken(sessionToken);
          }
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session: $e');
      return null;
    }
  }

  // Send Magic Link
  Future<bool> sendMagicLink(String email, String callbackUrl) async {
    try {
      final response = await _client.post(
        Uri.parse('$_backendUrl/api/auth/sign-in/magic-link'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'callbackURL': callbackUrl,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending magic link: $e');
      return false;
    }
  }

  // Get Google OAuth URL
  String getGoogleLoginUrl(String callbackUrl) {
    return '$_backendUrl/api/auth/login/social?provider=google&callbackURL=${Uri.encodeComponent(callbackUrl)}';
  }

  // Sign out
  Future<bool> signOut() async {
    try {
      await _client.post(
        Uri.parse('$_backendUrl/api/auth/sign-out'),
        headers: _getHeaders(),
        body: jsonEncode({}),
      );
      await _clearToken();
      return true;
    } catch (e) {
      debugPrint('Error signing out: $e');
      await _clearToken(); // Clear token even if network request fails
      return false;
    }
  }

  // List user organizations
  Future<List<dynamic>> listOrganizations() async {
    try {
      final response = await _client.get(
        Uri.parse('$_backendUrl/api/auth/organization/list'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error listing organizations: $e');
      return [];
    }
  }

  // Create an organization
  Future<Map<String, dynamic>?> createOrganization(String name, String slug) async {
    try {
      final response = await _client.post(
        Uri.parse('$_backendUrl/api/auth/organization/create'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'slug': slug,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating organization: $e');
      return null;
    }
  }
}
