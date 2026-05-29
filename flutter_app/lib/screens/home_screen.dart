import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/font_size_provider.dart';
import '../services/api_service.dart';
import '../models/tutorial.dart';
import 'tutorial_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Tutorial> _tutorials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTutorials();
  }

  Future<void> _loadTutorials() async {
    try {
      final result = await ApiService.getTutorials();
      if (result['success'] == true) {
        setState(() {
          _tutorials = (result['data'] as List).map((t) => Tutorial.fromJson(t)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  /// 通过 Android Intent 打开系统应用
  Future<void> _launchIntent(String action, {String? data}) async {
    final uri = data != null
        ? Uri.parse('intent:#Intent;action=$action;S.android.intent.extra.TEXT=$data;end')
        : Uri.parse('intent:#Intent;action=$action;end');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开该功能，请检查是否安装了对应应用')),
      );
    }
  }

  /// 快捷功能点击处理
  Future<void> _onQuickAccessTap(String label) async {
    Uri? uri;
    switch (label) {
      case '健康码':
        // 尝试打开微信健康码小程序（需用户已安装微信）
        uri = Uri.parse('weixin://dl/business/?t=healthcode');
        break;
      case '扫码':
        // 打开系统相机扫码（Android Intent）
        uri = Uri.parse('intent:#Intent;action=com.google.zxing.client.android.SCAN;end');
        break;
      case '乘车':
        // 打开支付宝乘车码
        uri = Uri.parse('alipays://platformapi/startapp?appId=20000134');
        break;
      case '缴费':
        // 打开支付宝生活缴费
        uri = Uri.parse('alipays://platformapi/startapp?appId=20000178');
        break;
      case '视频通话':
        // 打开微信
        uri = Uri.parse('weixin://');
        break;
      case '通讯录':
        // 打开系统通讯录
        uri = Uri.parse('content://contacts/people');
        break;
      case '拍照':
        // 打开系统相机
        uri = Uri.parse('intent:#Intent;action=android.media.action.STILL_IMAGE_CAMERA;end');
        break;
      case '地图':
        // 打开高德地图（如果安装了）或系统地图
        uri = Uri.parse('geo:0,0?q=当前位置');
        break;
      default:
        uri = null;
    }

    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未安装「$label」对应的应用')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开「$label」失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<FontSizeProvider>().scaled;
    return Scaffold(
      appBar: AppBar(title: const Text('智能助手'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        onRefresh: _loadTutorials,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 欢迎语
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('您好！', style: TextStyle(fontSize: s(28), color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('欢迎使用智能助手，有什么可以帮您的？', style: TextStyle(fontSize: s(18), color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 快捷功能入口
            Text('常用功能', style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _quickAccess(Icons.health_and_safety, '健康码'),
                _quickAccess(Icons.qr_code_scanner, '扫码'),
                _quickAccess(Icons.directions_bus, '乘车'),
                _quickAccess(Icons.payment, '缴费'),
                _quickAccess(Icons.video_call, '视频通话'),
                _quickAccess(Icons.contacts, '通讯录'),
                _quickAccess(Icons.camera_alt, '拍照'),
                _quickAccess(Icons.map, '地图'),
              ],
            ),
            const SizedBox(height: 24),

            // 推荐教程
            Text('推荐教程', style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_tutorials.isEmpty)
              Center(child: Text('暂无教程', style: TextStyle(fontSize: s(18), color: Colors.grey)))
            else
              ..._tutorials.map((t) => _tutorialCard(t)),
          ],
        ),
      ),
    );
  }

  Widget _quickAccess(IconData icon, String label) {
    final s = context.read<FontSizeProvider>().scaled;
    return GestureDetector(
      onTap: () => _onQuickAccessTap(label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF4A90E2)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: s(14)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tutorialCard(Tutorial tutorial) {
    final s = context.read<FontSizeProvider>().scaled;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book, size: 32, color: Color(0xFF4A90E2)),
        ),
        title: Text(tutorial.title, style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
        subtitle: Text(tutorial.description, style: TextStyle(fontSize: s(16)), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 20),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => TutorialDetailScreen(tutorial: tutorial)));
        },
      ),
    );
  }
}