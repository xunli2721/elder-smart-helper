import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class FontSizeProvider extends ChangeNotifier {
  String _fontSizeKey = 'large';

  String get fontSizeKey => _fontSizeKey;

  double get scaleFactor {
    switch (_fontSizeKey) {
      case 'small':
        return 0.8;
      case 'medium':
        return 0.9;
      case 'large':
        return 1.0;
      case 'xlarge':
        return 1.2;
      default:
        return 1.0;
    }
  }

  /// 将基准字号按当前缩放比例返回实际字号
  double scaled(double baseSize) => baseSize * scaleFactor;

  /// 从本地缓存加载字体设置
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSizeKey = prefs.getString('font_size') ?? 'large';
    notifyListeners();
  }

  /// 从服务端同步字体设置并更新本地缓存
  Future<void> loadFromApi() async {
    try {
      final result = await ApiService.getProfile();
      if (result['success'] == true) {
        final key = result['data']['font_size'] ?? 'large';
        _fontSizeKey = key;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('font_size', key);
        notifyListeners();
      }
    } catch (_) {
      // 网络失败时保持本地缓存值
    }
  }

  /// 更新字体大小：保存到服务端 + 本地缓存 + 通知 UI 刷新
  Future<bool> update(String key) async {
    try {
      final result = await ApiService.updateSettings(fontSize: key);
      if (result['success'] == true) {
        _fontSizeKey = key;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('font_size', key);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}