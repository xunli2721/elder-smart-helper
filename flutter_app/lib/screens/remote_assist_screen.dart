import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../providers/font_size_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/annotation_canvas.dart';

class RemoteAssistScreen extends StatefulWidget {
  const RemoteAssistScreen({super.key});

  @override
  State<RemoteAssistScreen> createState() => _RemoteAssistScreenState();
}

class _RemoteAssistScreenState extends State<RemoteAssistScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  List<dynamic> _family = [];
  List<dynamic> _sessions = [];
  Map<String, bool> _onlineStatus = {};
  bool _loading = true;
  int? _activeSessionId;
  final List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final familyResult = await ApiService.getFamily();
      final sessionResult = await ApiService.getRemoteSessions();
      final familyList = familyResult['success'] == true ? familyResult['data'] : [];

      // 查询家人在线状态
      Map<String, bool> onlineStatus = {};
      if (familyList.isNotEmpty) {
        final ids = (familyList as List).map((f) => f['id'] as int).toList();
        try {
          final statusResult = await ApiService.getOnlineStatus(ids);
          if (statusResult['success'] == true) {
            onlineStatus = Map<String, bool>.from(statusResult['data']);
          }
        } catch (_) {}
      }

      setState(() {
        _family = familyList;
        _sessions = sessionResult['success'] == true ? sessionResult['data'] : [];
        _onlineStatus = onlineStatus;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestAssist(int familyId, String familyName) async {
    try {
      final result = await ApiService.requestRemote(familyId, '请求远程协助');
      if (result['success'] == true) {
        final sessionId = result['data']['session_id'];
        setState(() => _activeSessionId = sessionId);

        await SocketService.connect();
        SocketService.joinSession(sessionId);
        _registerSocketListeners();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已向 $familyName 发起协助请求')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '发起失败')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    }
  }

  void _registerSocketListeners() {
    SocketService.removeAllListeners();

    // 文字消息
    SocketService.onMessage((data) {
      if (!mounted) return;
      setState(() {
        _messages.add({'type': 'text', 'text': data['message'], 'isMe': false, 'sender': data['sender']});
      });
    });

    // 截图消息
    SocketService.onScreenshot((data) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'type': 'screenshot',
          'imageBase64': data['image'],
          'isMe': false,
          'sender': data['sender'] ?? '对方',
        });
      });
    });

    // 标注消息
    SocketService.onAnnotation((data) {
      if (!mounted) return;
      final annotation = data['annotation'];
      if (annotation != null && annotation['imageBase64'] != null) {
        setState(() {
          _messages.add({
            'type': 'annotation',
            'imageBase64': annotation['imageBase64'],
            'isMe': false,
            'sender': data['sender'] ?? '对方',
          });
        });
      }
    });

    SocketService.onSessionEnded((data) {
      if (!mounted) return;
      setState(() => _activeSessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('协助会话已结束')));
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeSessionId == null) return;

    SocketService.sendMessage(_activeSessionId!, text, '我');
    setState(() {
      _messages.add({'type': 'text', 'text': text, 'isMe': true, 'sender': '我'});
    });
    _messageController.clear();
  }

  /// 截屏并发送
  Future<void> _takeScreenshot() async {
    if (_activeSessionId == null) return;
    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;

      final base64Image = base64Encode(imageBytes);
      SocketService.sendScreenshot(_activeSessionId!, base64Image);

      setState(() {
        _messages.add({
          'type': 'screenshot',
          'imageBase64': base64Image,
          'isMe': true,
          'sender': '我',
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('截图失败: $e')));
    }
  }

  /// 打开标注页面
  void _openAnnotation(String imageBase64) {
    final imageBytes = base64Decode(imageBase64);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnotationCanvas(
          imageBytes: imageBytes,
          onComplete: (annotatedBytes) {
            final annotatedBase64 = base64Encode(annotatedBytes);
            // 发送标注结果
            SocketService.sendAnnotation(_activeSessionId!, {
              'imageBase64': annotatedBase64,
            });
            setState(() {
              _messages.add({
                'type': 'annotation',
                'imageBase64': annotatedBase64,
                'isMe': true,
                'sender': '我',
              });
            });
            Navigator.pop(context);
          },
        ),
    );
  }

  void _endSession() {
    if (_activeSessionId != null) {
      SocketService.endSession(_activeSessionId!);
      SocketService.removeAllListeners();
      setState(() {
        _activeSessionId = null;
        _messages.clear();
      });
    }
  }

  @override
  void dispose() {
    SocketService.removeAllListeners();
    SocketService.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('远程协助'), automaticallyImplyLeading: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeSessionId != null) {
      return _buildChatScreen();
    }

    final s = context.read<FontSizeProvider>().scaled;
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程协助'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: '刷新'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('发起协助', style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_family.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.family_restroom, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('还没有绑定家人', style: TextStyle(fontSize: s(18), color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('请先到设置页面绑定家人账号', style: TextStyle(fontSize: s(16), color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ..._family.map((f) {
              final isOnline = _onlineStatus[f['id'].toString()] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Stack(
                    children: [
                      const CircleAvatar(radius: 24, child: Icon(Icons.person, size: 28)),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(f['name'], style: TextStyle(fontSize: s(20), fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${_relationshipText(f['relationship'])} · ${isOnline ? "在线" : "离线"}',
                    style: TextStyle(fontSize: s(16), color: isOnline ? Colors.green : Colors.grey),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _requestAssist(f['id'], f['name']),
                    child: const Text('求助'),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          Text('历史记录', style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_sessions.isEmpty)
            Center(child: Text('暂无协助记录', style: TextStyle(fontSize: s(18), color: Colors.grey)))
          else
            ..._sessions.map((s2) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(_statusIcon(s2['status']), size: 32, color: _statusColor(s2['status'])),
                title: Text(s2['elderly_name'] ?? s2['assistant_name'] ?? '未知', style: TextStyle(fontSize: s(18))),
                subtitle: Text(_statusText(s2['status']), style: TextStyle(fontSize: s(16))),
                trailing: Text(
                  s2['created_at']?.toString().substring(0, 16) ?? '',
                  style: TextStyle(fontSize: s(14), color: Colors.grey),
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildChatScreen() {
    final s = context.read<FontSizeProvider>().scaled;
    return Scaffold(
        appBar: AppBar(
          title: const Text('远程协助中'),
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('结束协助'),
                    content: const Text('确定要结束本次协助会话吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _endSession();
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('结束', style: TextStyle(color: Colors.white, fontSize: s(16))),
            ),
          ],
        ),
        body: Column(
          children: [
            // 消息列表
            Expanded(
              child: Screenshot(
                controller: _screenshotController,
                child: _messages.isEmpty
                  ? Center(child: Text('等待家人响应...\n可以发送消息或截图沟通', style: TextStyle(fontSize: s(18), color: Colors.grey), textAlign: TextAlign.center))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                    ),
              ),
            ),
            // 输入框 + 截图按钮
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  // 截图按钮
                  GestureDetector(
                    onTap: _takeScreenshot,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.camera_alt, color: Color(0xFF4A90E2), size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(fontSize: s(18)),
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: TextStyle(fontSize: s(18)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF4A90E2),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 24),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final s = context.read<FontSizeProvider>().scaled;
    final isMe = msg['isMe'] as bool;
    final type = msg['type'] as String? ?? 'text';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4A90E2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: type == 'text'
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(fontSize: s(18), color: isMe ? Colors.white : Colors.black87),
                  ),
                )
              : GestureDetector(
                  onTap: type == 'screenshot' ? () => _openAnnotation(msg['imageBase64']) : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        base64Decode(msg['imageBase64']),
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 40),
                        ),
                      ),
                      if (type == 'screenshot')
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('点击标注', style: TextStyle(color: Colors.white, fontSize: s(12))),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _relationshipText(String? rel) {
    switch (rel) {
      case 'child': return '子女';
      case 'spouse': return '配偶';
      case 'relative': return '亲属';
      case 'friend': return '朋友';
      case 'caregiver': return '护理人';
      default: return '家人';
    }
  }

  String _statusText(String? status) {
    switch (status) {
      case 'requested': return '等待响应';
      case 'active': return '进行中';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return '未知';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'requested': return Icons.hourglass_top;
      case 'active': return Icons.videocam;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'requested': return Colors.orange;
      case 'active': return Colors.green;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }
}