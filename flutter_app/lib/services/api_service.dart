import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:elder_smart_helper/config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _requestTimeout = Duration(seconds: 15);
  static String? _token;

  static Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    _token = await _storage.read(key: _tokenKey);
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await getToken();
    final uri = Uri.parse('$baseUrl$path');
    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response =
              await http.get(uri, headers: _headers).timeout(_requestTimeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: _headers, body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: _headers, body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: _headers)
              .timeout(_requestTimeout);
          break;
        default:
          throw Exception('Unsupported method');
      }
    } on Exception catch (e) {
      debugPrint('API request failed: $method $path - $e');
      rethrow;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('API error: ${response.statusCode} $method $path');
      // 尝试解析错误响应体，失败则返回通用错误
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'success': false, 'message': '服务器错误 (${response.statusCode})'};
      }
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Auth
  static Future<Map<String, dynamic>> register(
    String phone,
    String password,
    String name,
    String userType,
  ) async {
    return _request('POST', '/auth/register', body: {
      'phone': phone,
      'password': password,
      'name': name,
      'user_type': userType,
    });
  }

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    return _request('POST', '/auth/login',
        body: {'phone': phone, 'password': password});
  }

  static Future<Map<String, dynamic>> getProfile() async {
    return _request('GET', '/auth/profile');
  }

  // Tutorials
  static Future<Map<String, dynamic>> getTutorials({String? category}) async {
    final query = category != null ? '?category=$category' : '';
    return _request('GET', '/tutorials$query');
  }

  static Future<Map<String, dynamic>> getTutorialDetail(int id) async {
    return _request('GET', '/tutorials/$id');
  }

  // Family
  static Future<Map<String, dynamic>> bindFamily(
    String phone,
    String relationship,
  ) async {
    return _request('POST', '/users/bind',
        body: {'phone': phone, 'relationship': relationship});
  }

  static Future<Map<String, dynamic>> getFamily() async {
    return _request('GET', '/users/family');
  }

  static Future<Map<String, dynamic>> unbindFamily(int id) async {
    return _request('DELETE', '/users/family/$id');
  }

  // Settings
  static Future<Map<String, dynamic>> updateSettings({
    String? name,
    String? fontSize,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (fontSize != null) body['font_size'] = fontSize;
    return _request('PUT', '/users/settings', body: body);
  }

  // Remote
  static Future<Map<String, dynamic>> requestRemote(
    int assistantUserId,
    String? description,
  ) async {
    return _request('POST', '/remote/request', body: {
      'assistant_user_id': assistantUserId,
      'request_description': description ?? '',
    });
  }

  static Future<Map<String, dynamic>> getRemoteSessions() async {
    return _request('GET', '/remote/sessions');
  }

  static Future<Map<String, dynamic>> updateSessionStatus(
    int sessionId,
    String status,
  ) async {
    return _request('PUT', '/remote/sessions/$sessionId/status',
        body: {'status': status});
  }

  // Online Status
  static Future<Map<String, dynamic>> getOnlineStatus(
    List<int> userIds,
  ) async {
    return _request('POST', '/users/online-status',
        body: {'userIds': userIds});
  }

  // Security
  static Future<Map<String, dynamic>> checkFraud(String text) async {
    return _request('POST', '/security/check-fraud', body: {'text': text});
  }

  static Future<Map<String, dynamic>> checkPayment(double amount) async {
    return _request('POST', '/security/check-payment',
        body: {'amount': amount});
  }

  static Future<Map<String, dynamic>> getSecurityEvents({
    int? page,
    int? pageSize,
    String? severity,
  }) async {
    final params = <String>[];
    if (page != null) params.add('page=$page');
    if (pageSize != null) params.add('pageSize=$pageSize');
    if (severity != null) params.add('severity=$severity');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _request('GET', '/security/events$query');
  }

  static Future<Map<String, dynamic>> resolveSecurityEvent(
    int eventId,
  ) async {
    return _request('PUT', '/security/events/$eventId/resolve');
  }

  static Future<Map<String, dynamic>> getSecurityStats() async {
    return _request('GET', '/security/stats');
  }
}
