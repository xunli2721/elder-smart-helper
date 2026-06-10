import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _tutorials = (result['data'] as List).map((t) => Tutorial.fromJson(t)).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  /// 快捷功能点击处理
  Future<void> _onQuickAccessTap(String label) async {
    try {
      switch (label) {
        case '拍照':
          await _openCamera();
          return;
        case '通讯录':
          await _openContacts();
          return;
        case '扫码':
          await _openQrScanner();
          return;
      }

      // 以下功能依赖第三方 App，使用 url_launcher
      final uri = switch (label) {
        '健康码' => Uri.parse('weixin://dl/business/?t=healthcode'),
        '乘车' => Uri.parse('alipays://platformapi/startapp?appId=20000134'),
        '缴费' => Uri.parse('alipays://platformapi/startapp?appId=20000178'),
        '视频通话' => Uri.parse('weixin://'),
        '地图' => Uri.parse('https://uri.amap.com/marker?position=116.397428,39.90923'),
        _ => null,
      };

      if (uri != null) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          final appName = switch (label) {
            '健康码' || '乘车' || '缴费' || '视频通话' => '微信',
            '地图' => '地图应用',
            _ => label,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请先安装「$appName」后再使用此功能')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开「$label」失败: $e')),
      );
    }
  }

  Future<void> _openCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片已拍摄')),
      );
    }
  }

  Future<void> _openContacts() async {
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已选择联系人: ${contact.displayName}')),
        );
      }
    } else if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('通讯录权限被拒绝，请在设置中开启'),
          action: SnackBarAction(
            label: '去设置',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未授予通讯录权限')),
      );
    }
  }

  Future<void> _openQrScanner() async {
    if (!mounted) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫码结果: $result')),
      );
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
              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
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
            color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
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

/// 扫码页面
class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_scanned) return;
          final barcode = capture.barcodes.firstOrNull;
          if (barcode?.rawValue != null) {
            _scanned = true;
            Navigator.pop(context, barcode!.rawValue);
          }
        },
      ),
    );
  }
}