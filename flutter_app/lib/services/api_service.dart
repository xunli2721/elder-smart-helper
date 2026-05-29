import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // TODO: 修改为你的后端地址
  static const String baseUrl = 'http://10.0.2.2:3001/api';
  static String? _token;

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body}) async {
    await getToken();
    final uri = Uri.parse('$baseUrl$path');
    http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: _headers, body: jsonEncode(body));
        break;
      case 'PUT':
        response = await http.put(uri, headers: _headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: _headers);
        break;
      default:
        throw Exception('Unsupported method');
    }

    return jsonDecode(response.body);
  }

  // Auth
  static Future<Map<String, dynamic>> register(String phone, String password, String name, String userType) async {
    return _request('POST', '/auth/register', body: {
      'phone': phone, 'password': password, 'name': name, 'user_type': userType,
    });
  }

  static Future<Map<String, dynamic>> login(String phone, String password) async {
    return _request('POST', '/auth/login', body: {'phone': phone, 'password': password});
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
  static Future<Map<String, dynamic>> bindFamily(String phone, String relationship) async {
    return _request('POST', '/users/bind', body: {'phone': phone, 'relationship': relationship});
  }

  static Future<Map<String, dynamic>> getFamily() async {
    return _request('GET', '/users/family');
  }

  static Future<Map<String, dynamic>> unbindFamily(int id) async {
    return _request('DELETE', '/users/family/$id');
  }

  // Settings
  static Future<Map<String, dynamic>> updateSettings({String? name, String? fontSize}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (fontSize != null) body['font_size'] = fontSize;
    return _request('PUT', '/users/settings', body: body);
  }

  // Remote
  static Future<Map<String, dynamic>> requestRemote(int assistantUserId, String? description) async {
    return _request('POST', '/remote/request', body: {
      'assistant_user_id': assistantUserId,
      'request_description': description ?? '',
    });
  }

  static Future<Map<String, dynamic>> getRemoteSessions() async {
    return _request('GET', '/remote/sessions');
  }

  static Future<Map<String, dynamic>> updateSessionStatus(int sessionId, String status) async {
    return _request('PUT', '/remote/sessions/$sessionId/status', body: {'status': status});
  }

  // Online Status
  static Future<Map<String, dynamic>> getOnlineStatus(List<int> userIds) async {
    return _request('POST', '/users/online-status', body: {'userIds': userIds});
  }  
}
