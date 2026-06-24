import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../providers/font_size_provider.dart';
import '../config/theme.dart';
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

      // 打电话：从通讯录选人后拨号
      if (label == '打电话') {
        await _makePhoneCall();
        return;
      }

      // 地图：优先高德地图 App
      if (label == '地图') {
        await _openMap();
        return;
      }

      // 天气：打开手机自带天气 App
      if (label == '天气') {
        if (Platform.isAndroid) {
          final weatherPackages = [
            'com.honor.weather',                // 荣耀天气
            'com.huawei.android.totemweather',  // 华为天气
            'com.miui.weather2',                // 小米天气
            'com.coloros.weather2',             // OPPO 天气
            'com.sec.android.daemonapp',        // 三星天气
            'com.transsion.weather',            // 传音天气
            'com.google.android.apps.weather',  // Google 天气
          ];
          for (final package in weatherPackages) {
            final packageUri = Uri.parse('package:$package');
            if (await canLaunchUrl(packageUri)) {
              final intent = AndroidIntent(
                action: 'android.intent.action.MAIN',
                package: package,
                flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
              );
              await intent.launch();
              return;
            }
          }
        }
        // 备选：打开中国天气网
        final uri = Uri.parse('http://www.weather.com.cn');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      }

      // 支付宝缴费
      if (label == '支付宝缴费') {
        final uri = Uri.parse('alipays://platformapi/startapp?appId=20000178');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先安装「支付宝」后再使用此功能')),
          );
        }
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开「$label」失败，请重试')),
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
      if (contact == null || !mounted) return;
      // Android Intent 打开联系人详情页（可看通话记录）
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data:
              'content://com.android.contacts/contacts/${contact.id}',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
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
    if (result == null || !mounted) return;
    await _handleScanResult(result);
  }

  /// 智能处理扫码结果
  Future<void> _handleScanResult(String result) async {
    final trimmed = result.trim();

    // 空结果
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('扫码结果为空')),
      );
      return;
    }

    // 微信 scheme 链接
    if (trimmed.startsWith('weixin://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // 支付宝 scheme 链接
    if (trimmed.startsWith('alipay://') ||
        trimmed.startsWith('alipays://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // URL（https 或 http）
    if (trimmed.startsWith('https://') ||
        trimmed.startsWith('http://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无效的链接')),
        );
        return;
      }

      // 检测微信相关域名，跳转微信打开
      final host = uri.host.toLowerCase();
      if (host.contains('weixin.qq.com') ||
          host.contains('wechat.com')) {
        final wechatUri = Uri.parse('weixin://');
        if (await canLaunchUrl(wechatUri)) {
          await launchUrl(wechatUri,
              mode: LaunchMode.externalApplication);
          return;
        }
      }

      // 其他 URL → 打开浏览器
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // 其他文本 → 弹窗显示
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫码结果'),
        content: SelectableText(trimmed),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 打电话：从通讯录选人后拨号
  Future<void> _makePhoneCall() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未授予通讯录权限')),
        );
      }
      return;
    }

    final contact = await FlutterContacts.openExternalPick();
    if (contact == null) return;

    // 获取完整联系人信息（包含电话号码）
    final fullContact = await FlutterContacts.getContact(contact.id);
    if (!mounted) return;
    if (fullContact == null || fullContact.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该联系人没有电话号码')),
      );
      return;
    }

    // 清理电话号码中的特殊字符
    final phone = fullContact.phones.first.number
        .replaceAll(RegExp(r'[^\d+#*]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('电话号码格式无效')),
      );
      return;
    }

    final telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }
  }

  /// 打开地图：优先高德地图 App，失败则打开网页
  Future<void> _openMap() async {
    // 高德地图 App scheme
    final amapUri = Uri.parse('amapuri://map/marker?position=116.397428,39.90923&name=当前位置');
    // 网页备用
    final webUri = Uri.parse('https://uri.amap.com/marker?position=116.397428,39.90923');

    // 优先尝试高德地图 App
    if (await canLaunchUrl(amapUri)) {
      await launchUrl(amapUri, mode: LaunchMode.externalApplication);
      return;
    }

    // 回退到网页版
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开地图，请检查网络连接')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<FontSizeProvider>().scaled;
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
                color: AppColors.primary,
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
                _quickAccess(Icons.qr_code_scanner, '扫码'),
                _quickAccess(Icons.wb_sunny, '天气'),
                _quickAccess(Icons.payment, '支付宝缴费'),
                _quickAccess(Icons.phone, '打电话'),
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
    final s = context.watch<FontSizeProvider>().scaled;
    return GestureDetector(
      onTap: () => _onQuickAccessTap(label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: s(14)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tutorialCard(Tutorial tutorial) {
    final s = context.watch<FontSizeProvider>().scaled;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu_book, size: 32, color: AppColors.primary),
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