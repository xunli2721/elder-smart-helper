import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

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
        } catch (_) {
          // 在线状态查询失败不影响主流程
        }
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

        // 连接 WebSocket 并注册监听
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

  /// 统一注册 Socket 事件监听，避免重复注册
  void _registerSocketListeners() {
    SocketService.removeAllListeners();
    SocketService.onMessage((data) {
      if (!mounted) return;
      setState(() {
        _messages.add({'text': data['message'], 'isMe': false, 'sender': data['sender']});
      });
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
      _messages.add({'text': text, 'isMe': true, 'sender': '我'});
    });
    _messageController.clear();
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

    // 如果有活跃会话，显示聊天界面
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
            tooltip: '刷新',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 发起协助
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

          // 历史记录
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
            child: _messages.isEmpty
                ? Center(child: Text('等待家人响应...\n可以发送消息沟通', style: TextStyle(fontSize: s(18), color: Colors.grey), textAlign: TextAlign.center))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg['isMe'] ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: msg['isMe'] ? const Color(0xFF4A90E2) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['text'],
                            style: TextStyle(fontSize: s(18), color: msg['isMe'] ? Colors.white : Colors.black87),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // 输入框
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
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