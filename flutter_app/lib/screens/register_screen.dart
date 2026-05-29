import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';
import '../services/api_service.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _userType = 'elderly';
  bool _loading = false;

  Future<void> _register() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    if (phone.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整信息')));
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiService.register(phone, password, name, _userType);
      if (result['success'] == true) {
        await ApiService.setToken(result['data']['token']);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '注册失败')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<FontSizeProvider>().scaled;
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: TextStyle(fontSize: s(20)),
              decoration: const InputDecoration(labelText: '姓名', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: s(20)),
              decoration: const InputDecoration(labelText: '手机号', prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: TextStyle(fontSize: s(20)),
              decoration: const InputDecoration(labelText: '密码', prefixIcon: Icon(Icons.lock)),
            ),
            const SizedBox(height: 24),
            Text('请选择身份：', style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _userType = 'elderly'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _userType == 'elderly' ? const Color(0xFF4A90E2) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.elderly, size: 40, color: _userType == 'elderly' ? Colors.white : Colors.black54),
                          const SizedBox(height: 8),
                          Text('我是老人', style: TextStyle(
                            fontSize: s(18),
                            color: _userType == 'elderly' ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _userType = 'family'),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _userType == 'family' ? const Color(0xFF4A90E2) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.family_restroom, size: 40, color: _userType == 'family' ? Colors.white : Colors.black54),
                          const SizedBox(height: 8),
                          Text('我是家人', style: TextStyle(
                            fontSize: s(18),
                            color: _userType == 'family' ? Colors.white : Colors.black54,
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('注册'),
            ),
          ],
        ),
      ),
    );
  }
}