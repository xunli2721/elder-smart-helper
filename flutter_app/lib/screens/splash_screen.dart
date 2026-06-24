import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final fontProvider = context.read<FontSizeProvider>();

    // 并行：加载本地字体设置 + 检查 token
    await Future.wait([
      fontProvider.loadFromPrefs(),
      _tryAutoLogin(fontProvider),
    ]);
  }

  Future<void> _tryAutoLogin(FontSizeProvider fontProvider) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        _goToLogin();
        return;
      }

      final result = await ApiService.getProfile();
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        // 同步服务端字体设置
        final serverFontSize = result['data']['font_size']?.toString() ?? 'large';
        await fontProvider.setFromServer(serverFontSize);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        await ApiService.clearToken();
        _goToLogin();
      }
    } catch (_) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              '智能助手',
              style: TextStyle(
                fontSize: context.watch<FontSizeProvider>().scaled(36),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '中老年人智能手机助手',
              style: TextStyle(fontSize: context.watch<FontSizeProvider>().scaled(18), color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}