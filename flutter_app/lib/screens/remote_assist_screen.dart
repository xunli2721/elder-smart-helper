import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:elder_smart_helper/providers/font_size_provider.dart';
import 'package:elder_smart_helper/services/api_service.dart';
import 'package:elder_smart_helper/services/socket_service.dart';
import 'package:elder_smart_helper/widgets/annotation_canvas.dart';
import 'package:elder_smart_helper/utils/remote_assist_utils.dart';

class RemoteAssistScreen extends StatefulWidget {
  const RemoteAssistScreen({super.key});

  @override
  State<RemoteAssistScreen> createState() => _RemoteAssistScreenState();
}

class _RemoteAssistScreenState extends State<RemoteAssistScreen> {
  List<dynamic> _family = [];
  List<dynamic> _sessions = [];
  Map<String, bool> _onlineStatus = {};
  bool _loading = true;
  int? _activeSessionId;
  int? _currentUserId;
  final List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 并行获取用户信息、家人列表、会话列表
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getFamily(),
        ApiService.getRemoteSessions(),
      ]);
      final profileResult = results[0];
      final familyResult = results[1];
      final sessionResult = results[2];

      // 获取当前用户 ID
      if (profileResult['success'] == true && profileResult['data'] != null) {
        final id = profileResult['data']['id'];
        _currentUserId = id is int ? id : int.tryParse(id.toString());
      }
      final familyList =
          (familyResult['success'] == true && familyResult['data'] != null)
              ? familyResult['data'] as List
              : <dynamic>[];

      Map<String, bool> onlineStatus = {};
      if (familyList.isNotEmpty) {
        final ids = familyList
            .map((f) => f['id'])
            .where((id) => id != null)
            .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
            .toList();
        if (ids.isNotEmpty) {
          try {
            final statusResult = await ApiService.getOnlineStatus(ids);
            if (statusResult['success'] == true &&
                statusResult['data'] != null) {
              final data = statusResult['data'];
              if (data is Map) {
                onlineStatus = Map.fromEntries(
                  data.entries
                      .map((e) => MapEntry(e.key.toString(), e.value == true)),
                );
              }
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;
      setState(() {
        _family = familyList;
        _sessions =
            (sessionResult['success'] == true && sessionResult['data'] != null)
                ? sessionResult['data'] as List
                : <dynamic>[];
        _onlineStatus = onlineStatus;
        _loading = false;
      });
    } catch (e) {
      debugPrint('加载远程协助数据失败: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _requestAssist(int familyId, String familyName) async {
    try {
      final result = await ApiService.requestRemote(familyId, '请求远程协助');
      if (result['success'] == true && result['data'] != null) {
        final sessionId = result['data']['session_id'];
        if (sessionId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('创建会话失败')));
          return;
        }
        setState(() => _activeSessionId =
            sessionId is int ? sessionId : int.tryParse(sessionId.toString()));

        try {
          await SocketService.connect(userId: _currentUserId);
        } catch (e) {
          debugPrint('Socket 连接失败: $e');
          if (mounted) {
            setState(() => _activeSessionId = null);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('连接失败，请检查网络后重试')));
          }
          return;
        }

        if (_activeSessionId != null) {
          SocketService.joinSession(_activeSessionId!);
          _registerSocketListeners();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已向 $familyName 发起协助请求')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? '发起失败')));
      }
    } catch (e) {
      debugPrint('发起协助失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('网络连接失败，请检查网络后重试')));
    }
  }

  void _registerSocketListeners() {
    SocketService.removeAllListeners();

    SocketService.onMessage((data) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'type': 'text',
          'text': data['message'],
          'isMe': false,
          'sender': data['sender'],
        });
      });
      _scrollToBottom();
    });

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
      _scrollToBottom();
    });

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
        _scrollToBottom();
      }
    });

    SocketService.onSessionEnded((data) {
      if (!mounted) return;
      setState(() => _activeSessionId = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('协助会话已结束')));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _activeSessionId == null) return;

    SocketService.sendMessage(_activeSessionId!, text, '我');
    setState(() {
      _messages
          .add({'type': 'text', 'text': text, 'isMe': true, 'sender': '我'});
    });
    _messageController.clear();
    _scrollToBottom();
  }

  /// 选择图片并发送（拍照 / 从相册选择）
  void _showImageSourcePicker() {
    if (_activeSessionId == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (_activeSessionId == null) return;
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 70,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      SocketService.sendScreenshot(_activeSessionId!, base64Image);

      if (!mounted) return;
      setState(() {
        _messages.add({
          'type': 'screenshot',
          'imageBase64': base64Image,
          'isMe': true,
          'sender': '我',
        });
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('图片发送失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('图片发送失败，请重试')));
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
            if (_activeSessionId == null) return;
            final annotatedBase64 = base64Encode(annotatedBytes);
            SocketService.sendAnnotation(
                _activeSessionId!, {'imageBase64': annotatedBase64});
            if (mounted) {
              setState(() {
                _messages.add({
                  'type': 'annotation',
                  'imageBase64': annotatedBase64,
                  'isMe': true,
                  'sender': '我',
                });
              });
              _scrollToBottom();
            }
          },
        ),
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

  Future<void> _respondSession(int sessionId, String newStatus) async {
    try {
      final result = await ApiService.updateSessionStatus(sessionId, newStatus);
      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(newStatus == 'active' ? '已接受请求' : '已拒绝请求')),
        );
        await _loadData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '操作失败')),
        );
      }
    } catch (e) {
      debugPrint('响应协助请求失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失败，请检查网络后重试')));
    }
  }

  void _onSessionTap(int sessionId, String status) {
    if (status == 'active') {
      setState(() => _activeSessionId = sessionId);
      SocketService.connect(userId: _currentUserId).then((_) {
        if (!mounted) return;
        SocketService.joinSession(sessionId);
        _registerSocketListeners();
      }).catchError((e) {
        debugPrint('重新加入会话失败: $e');
        if (mounted) {
          setState(() => _activeSessionId = null);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('连接失败，请检查网络后重试')));
        }
      });
    } else if (status == 'requested') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先接受或拒绝此请求')),
      );
    }
  }

  @override
  void dispose() {
    SocketService.removeAllListeners();
    SocketService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('远程协助'), automaticallyImplyLeading: false),
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
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: '刷新'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('发起协助',
              style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_family.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.family_restroom,
                        size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('还没有绑定家人',
                        style:
                            TextStyle(fontSize: s(18), color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('请先到设置页面绑定家人账号',
                        style:
                            TextStyle(fontSize: s(16), color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ..._family.map((f) {
              final isOnline = _onlineStatus[f['id']?.toString()] == true;
              final name = f['name']?.toString() ?? '未知';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          const CircleAvatar(
                              radius: 24, child: Icon(Icons.person, size: 28)),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: TextStyle(
                                    fontSize: s(20),
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${relationshipText(f['relationship']?.toString())} · ${isOnline ? "在线" : "离线"}',
                              style: TextStyle(
                                  fontSize: s(16),
                                  color:
                                      isOnline ? Colors.green : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (f['id'] != null)
                        SizedBox(
                          width: 72,
                          child: ElevatedButton(
                            onPressed: () =>
                                _requestAssist(f['id'] as int, name),
                            child: const Text('求助'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          Text('历史记录',
              style: TextStyle(fontSize: s(22), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_sessions.isEmpty)
            Center(
                child: Text('暂无协助记录',
                    style: TextStyle(fontSize: s(18), color: Colors.grey)))
          else
            ..._sessions.map((session) {
              final createdAt = session['created_at']?.toString() ?? '';
              final displayTime =
                  createdAt.length >= 16 ? createdAt.substring(0, 16) : createdAt;
              final status = session['status']?.toString();
              final sessionId = session['id'] is int
                  ? session['id'] as int
                  : int.tryParse(session['id']?.toString() ?? '');
              final canTap = status == 'active' || status == 'requested';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: canTap && sessionId != null
                      ? () => _onSessionTap(sessionId, status!)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(sessionStatusIcon(status),
                            size: 32, color: sessionStatusColor(status)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  session['elderly_name']?.toString() ??
                                      session['assistant_name']?.toString() ??
                                      '未知',
                                  style: TextStyle(fontSize: s(18))),
                              const SizedBox(height: 4),
                              Text(sessionStatusText(status),
                                  style: TextStyle(
                                      fontSize: s(16),
                                      color: sessionStatusColor(status))),
                            ],
                          ),
                        ),
                        if (status == 'requested')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: sessionId != null
                                    ? () =>
                                        _respondSession(sessionId, 'active')
                                    : null,
                                child: const Text('接受'),
                              ),
                              TextButton(
                                onPressed: sessionId != null
                                    ? () => _respondSession(
                                        sessionId, 'cancelled')
                                    : null,
                                child: const Text('拒绝',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          )
                        else
                          Text(
                            displayTime,
                            style: TextStyle(
                                fontSize: s(14), color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
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
            child:
                Text('结束', style: TextStyle(color: Colors.white, fontSize: s(16))),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      '等待家人响应...\n可以发送消息或图片沟通',
                      style: TextStyle(fontSize: s(18), color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),
          // 输入框 + 截图按钮
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showImageSourcePicker,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Color(0xFF4A90E2), size: 24),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF4A90E2),
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.white, size: 24),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4A90E2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: type == 'text'
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                        fontSize: s(18),
                        color: isMe ? Colors.white : Colors.black87),
                  ),
                )
              : GestureDetector(
                  onTap: type == 'screenshot'
                      ? () => _openAnnotation(msg['imageBase64'])
                      : null,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('点击标注',
                                style: TextStyle(
                                    color: Colors.white, fontSize: s(12))),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
