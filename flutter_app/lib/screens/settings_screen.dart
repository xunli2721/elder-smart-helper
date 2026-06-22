import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String _phone = '';
  String _userType = '';
  String _fontSize = 'large';
  String _speechRate = 'slow';
  bool _loading = true;
  final _nameController = TextEditingController();
  final _phoneBindController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await ApiService.getProfile();
      final provider = context.read<FontSizeProvider>();
      if (result['success'] == true) {
        final user = result['data'];
        setState(() {
          _name = user['name']?.toString() ?? '';
          _phone = user['phone']?.toString() ?? '';
          _userType = user['user_type']?.toString() ?? '';
          _fontSize = user['font_size']?.toString() ?? 'large';
          _speechRate = provider.speechRate;
          _nameController.text = _name;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateFontSize(String size) async {
    final provider = context.read<FontSizeProvider>();
    final success = await provider.update(size);
    if (!mounted) return;
    if (success) {
      setState(() => _fontSize = size);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('字体大小已更新')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
    }
  }

  Future<void> _updateSpeechRate(String rate) async {
    final provider = context.read<FontSizeProvider>();
    await provider.updateSpeechRate(rate);
    setState(() => _speechRate = rate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('播报语速已更新')));
  }

  Future<void> _updateName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final result = await ApiService.updateSettings(name: name);
      if (result['success'] == true) {
        setState(() => _name = name);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('姓名已更新')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('退出登录', style: TextStyle(fontSize: context.read<FontSizeProvider>().scaled(24))),
        content: Text('确定要退出登录吗？', style: TextStyle(fontSize: context.read<FontSizeProvider>().scaled(18))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(fontSize: context.read<FontSizeProvider>().scaled(18)))),
          TextButton(
            onPressed: () async {
              await ApiService.clearToken();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text('确定', style: TextStyle(fontSize: context.read<FontSizeProvider>().scaled(18), color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneBindController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置'), automaticallyImplyLeading: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final s = context.read<FontSizeProvider>().scaled;
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 个人信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 48)),
                  const SizedBox(height: 16),
                  Text(_name, style: TextStyle(fontSize: s(24), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_phone, style: TextStyle(fontSize: s(18), color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(_userType == 'elderly' ? '老人用户' : '家人用户', style: TextStyle(fontSize: s(16), color: const Color(0xFF4A90E2))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 修改姓名
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('修改姓名', style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: TextStyle(fontSize: s(18)),
                          decoration: InputDecoration(
                            hintText: '输入新姓名',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _updateName,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 字体大小设置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('字体大小', style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _fontSizeOption('small', '小', 14),
                      _fontSizeOption('medium', '中', 16),
                      _fontSizeOption('large', '大', 18),
                      _fontSizeOption('xlarge', '超大', 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 播报语速设置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('播报语速', style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('教程朗读时的语音速度', style: TextStyle(fontSize: s(14), color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _speechRateOption('slow', '慢速'),
                      _speechRateOption('medium', '中速'),
                      _speechRateOption('fast', '快速'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 绑定家人（仅老人用户）
          if (_userType == 'elderly') _buildBindFamilyCard(),
          if (_userType == 'elderly') const SizedBox(height: 16),

          // 关于
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('关于', style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('智能助手 v1.0.0', style: TextStyle(fontSize: s(18))),
                  const SizedBox(height: 4),
                  Text('专为中老年人设计的智能手机使用助手', style: TextStyle(fontSize: s(16), color: Colors.grey[600])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 退出登录
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  Widget _fontSizeOption(String size, String label, double previewSize) {
    final s = context.read<FontSizeProvider>().scaled;
    final isSelected = _fontSize == size;
    return GestureDetector(
      onTap: () => _updateFontSize(size),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('字', style: TextStyle(fontSize: s(previewSize), color: isSelected ? Colors.white : Colors.black87)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: s(16),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF4A90E2) : Colors.black87,
          )),
        ],
      ),
    );
  }

  Widget _speechRateOption(String rate, String label) {
    final s = context.read<FontSizeProvider>().scaled;
    final isSelected = _speechRate == rate;
    IconData icon;
    switch (rate) {
      case 'slow':
        icon = Icons.slow_motion_video;
        break;
      case 'medium':
        icon = Icons.speed;
        break;
      case 'fast':
        icon = Icons.fast_forward;
        break;
      default:
        icon = Icons.speed;
    }
    return GestureDetector(
      onTap: () => _updateSpeechRate(rate),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, size: 28, color: isSelected ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: s(16),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF4A90E2) : Colors.black87,
          )),
        ],
      ),
    );
  }

  Widget _buildBindFamilyCard() {
    final s = context.read<FontSizeProvider>().scaled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('绑定家人', style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneBindController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: s(18)),
                    decoration: InputDecoration(
                      hintText: '输入家人手机号',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final phone = _phoneBindController.text.trim();
                    if (phone.isEmpty) return;
                    final result = await ApiService.bindFamily(phone, 'child');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['success'] == true ? '绑定成功' : (result['message']?.toString() ?? '绑定失败'))),
                    );
                    _phoneBindController.clear();
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
                  child: const Text('绑定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}