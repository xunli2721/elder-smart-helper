import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:elder_smart_helper/providers/font_size_provider.dart';
import 'package:elder_smart_helper/config/theme.dart';
import 'package:elder_smart_helper/services/api_service.dart';
import 'package:elder_smart_helper/services/socket_service.dart';
import 'package:elder_smart_helper/services/screen_capture_service.dart';
import 'package:elder_smart_helper/widgets/annotation_canvas.dart';
import 'package:elder_smart_helper/utils/remote_assist_utils.dart';
import 'package:elder_smart_helper/models/tutorial.dart';
import 'package:elder_smart_helper/screens/tutorial_detail_screen.dart';

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
  final List<Map<String, dynamic>> _guideMarks = [];
  bool _isSharingScreen = false;
  bool _isViewingScreen = false;
  String? _currentScreenFrame;
  int _remoteScreenWidth = 720;
  int _remoteScreenHeight = 1280;
  StreamSubscription? _frameSubscription;
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

    SocketService.onScreenFrame((data) {
      if (!mounted) return;
      final image = data['image'] as String?;
      if (image != null && image.isNotEmpty) {
        setState(() {
          _currentScreenFrame = image;
          _remoteScreenWidth = data['width'] ?? 720;
          _remoteScreenHeight = data['height'] ?? 1280;
          _isViewingScreen = true;
        });
      }
    });

    SocketService.onTutorial((data) {
      if (!mounted) return;
      final tutorial = data['tutorial'];
      if (tutorial != null) {
        setState(() {
          _messages.add({
            'type': 'tutorial',
            'tutorial': tutorial,
            'isMe': false,
            'sender': data['sender'] ?? '对方',
          });
        });
        _scrollToBottom();
      }
    });

    SocketService.onGuideMark((data) {
      if (!mounted) return;
      final mark = data['mark'];
      if (mark != null) {
        setState(() {
          _guideMarks.add({
            'id': mark['id'],
            'x': mark['x'],
            'y': mark['y'],
            'order': mark['order'],
            'imageBase64': mark['imageBase64'],
          });
        });
        // 显示引导覆盖层
        _showGuideOverlay(mark['imageBase64']);
      }
    });

    SocketService.onGuideConfirm((data) {
      if (!mounted) return;
      final markId = data['markId'];
      setState(() {
        _guideMarks.removeWhere((m) => m['id'] == markId);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('对方已完成引导步骤')));
    });

    SocketService.onSessionEnded((data) {
      if (!mounted) return;
      setState(() {
        _activeSessionId = null;
        _guideMarks.clear();
      });
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

  /// 显示教程选择弹窗
  Future<void> _showTutorialPicker() async {
    if (_activeSessionId == null) return;
    try {
      final result = await ApiService.getTutorials();
      if (!mounted) return;
      if (result['success'] != true || result['data'] == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('加载教程失败')));
        return;
      }
      final tutorials = (result['data'] as List)
          .map((t) => Tutorial.fromJson(t))
          .toList();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('选择教程',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: tutorials.length,
                  itemBuilder: (ctx, index) {
                    final t = tutorials[index];
                    return ListTile(
                      leading: const Icon(Icons.menu_book,
                          color: AppColors.primary),
                      title: Text(t.title),
                      subtitle: Text(t.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendTutorial(t);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('加载教程失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('加载教程失败')));
    }
  }

  /// 显示引导覆盖层（老人端收到标记后）
  void _showGuideOverlay(String? imageBase64) {
    if (imageBase64 == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('家人正在引导您',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxWidth,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.memory(
                                    base64Decode(imageBase64),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                ..._guideMarks.where((m) =>
                                    m['imageBase64'] == imageBase64).map((mark) {
                                  final x = (mark['x'] as num).toDouble();
                                  final y = (mark['y'] as num).toDouble();
                                  return Positioned(
                                    left: x * constraints.maxWidth - 18,
                                    top: y * constraints.maxWidth - 18,
                                    child: _GuideMarkWidget(
                                      order: mark['order'] ?? 1,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('关闭'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // 确认完成
                            for (final mark in _guideMarks) {
                              if (_activeSessionId != null) {
                                SocketService.sendGuideConfirm(
                                    _activeSessionId!, mark['id']);
                              }
                            }
                            setState(() => _guideMarks.clear());
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已确认完成')),
                            );
                          },
                          child: const Text('确认完成'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 开始屏幕共享
  Future<void> _startScreenShare() async {
    if (_activeSessionId == null) return;
    try {
      final started = await ScreenCaptureService.startCapture();
      if (!started) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法开始屏幕共享，请授权屏幕录制权限')),
        );
        return;
      }
      setState(() => _isSharingScreen = true);

      // 监听屏幕帧并通过 Socket 发送
      _frameSubscription = ScreenCaptureService.frameStream?.listen((frame) {
        if (_activeSessionId != null && _isSharingScreen) {
          SocketService.sendScreenFrame(
            _activeSessionId!,
            frame.imageBase64,
            frame.width,
            frame.height,
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('屏幕共享已开始')),
      );
    } catch (e) {
      debugPrint('startScreenShare error: $e');
    }
  }

  /// 停止屏幕共享
  Future<void> _stopScreenShare() async {
    _frameSubscription?.cancel();
    _frameSubscription = null;
    await ScreenCaptureService.stopCapture();
    setState(() => _isSharingScreen = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('屏幕共享已停止')),
    );
  }

  /// 在共享的屏幕上标注（考虑 BoxFit.contain 的 letterbox 偏移）
  void _markOnSharedScreen(
    Offset tapPosition,
    Size containerSize,
    Size imageActualSize,
  ) {
    if (_activeSessionId == null) return;

    // 计算 BoxFit.contain 后图片的实际显示区域
    final imageAspect = imageActualSize.width / imageActualSize.height;
    final containerAspect = containerSize.width / containerSize.height;

    double displayWidth, displayHeight, offsetX, offsetY;
    if (imageAspect > containerAspect) {
      // 图片更宽，左右填满，上下有 letterbox
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - displayHeight) / 2;
    } else {
      // 图片更高，上下填满，左右有 letterbox
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAspect;
      offsetX = (containerSize.width - displayWidth) / 2;
      offsetY = 0;
    }

    // 将点击位置转换为图片内的比例坐标
    final ratioX =
        ((tapPosition.dx - offsetX) / displayWidth).clamp(0.0, 1.0);
    final ratioY =
        ((tapPosition.dy - offsetY) / displayHeight).clamp(0.0, 1.0);

    final markId = DateTime.now().millisecondsSinceEpoch;
    SocketService.sendGuideMark(_activeSessionId!, {
      'id': markId,
      'x': ratioX,
      'y': ratioY,
      'order': _guideMarks.length + 1,
      'imageBase64': _currentScreenFrame,
    }, '我');

    if (mounted) {
      setState(() {
        _guideMarks.add({
          'id': markId,
          'x': ratioX,
          'y': ratioY,
          'order': _guideMarks.length + 1,
          'imageBase64': _currentScreenFrame,
        });
      });
    }
  }

  void _sendTutorial(Tutorial tutorial) {
    if (_activeSessionId == null) return;
    final tutorialData = {
      'id': tutorial.id,
      'title': tutorial.title,
      'description': tutorial.description,
    };
    SocketService.sendTutorial(_activeSessionId!, tutorialData, '我');
    setState(() {
      _messages.add({
        'type': 'tutorial',
        'tutorial': tutorialData,
        'isMe': true,
        'sender': '我',
      });
    });
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
          onComplete: (annotatedBytes, {guideMarks}) {
            if (_activeSessionId == null) return;
            final annotatedBase64 = base64Encode(annotatedBytes);

            // 如果有引导标记，发送引导标记事件
            if (guideMarks != null && guideMarks.isNotEmpty) {
              for (final mark in guideMarks) {
                SocketService.sendGuideMark(_activeSessionId!, {
                  'id': DateTime.now().millisecondsSinceEpoch + mark.order,
                  'x': mark.ratioX,
                  'y': mark.ratioY,
                  'imageWidth': 1.0,
                  'imageHeight': 1.0,
                  'order': mark.order,
                  'imageBase64': annotatedBase64,
                }, '我');
              }
              if (mounted) {
                setState(() {
                  _messages.add({
                    'type': 'guide_sent',
                    'imageBase64': annotatedBase64,
                    'markCount': guideMarks.length,
                    'isMe': true,
                    'sender': '我',
                  });
                });
                _scrollToBottom();
              }
            } else {
              // 普通标注
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
      if (_isSharingScreen) {
        _frameSubscription?.cancel();
        _frameSubscription = null;
        ScreenCaptureService.stopCapture();
      }
      setState(() {
        _activeSessionId = null;
        _messages.clear();
        _guideMarks.clear();
        _isSharingScreen = false;
        _isViewingScreen = false;
        _currentScreenFrame = null;
        _remoteScreenWidth = 720;
        _remoteScreenHeight = 1280;
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
    _frameSubscription?.cancel();
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

    final s = context.watch<FontSizeProvider>().scaled;
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
    final s = context.watch<FontSizeProvider>().scaled;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSharingScreen ? '正在共享屏幕' : '远程协助中'),
        actions: [
          // 屏幕共享按钮
          IconButton(
            icon: Icon(
              _isSharingScreen ? Icons.stop_screen_share : Icons.screen_share,
              color: Colors.white,
            ),
            tooltip: _isSharingScreen ? '停止共享' : '共享屏幕',
            onPressed: _isSharingScreen ? _stopScreenShare : _startScreenShare,
          ),
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
          // 共享屏幕显示区域（家人端查看老人屏幕）
          if (_isViewingScreen && _currentScreenFrame != null)
            _buildSharedScreenView(),
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: AppColors.primary, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showTutorialPicker,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.menu_book,
                        color: AppColors.primary, size: 24),
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
                  backgroundColor: AppColors.primary,
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

  /// 共享屏幕视图（家人端查看并标注）
  Widget _buildSharedScreenView() {
    return Container(
      height: 280,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            // 计算 BoxFit.contain 后图片的实际显示区域
            final imgW = _remoteScreenWidth.toDouble();
            final imgH = _remoteScreenHeight.toDouble();
            final imgAspect = imgW / imgH;
            final containerAspect = w / h;
            double displayW, displayH, offX, offY;
            if (imgAspect > containerAspect) {
              displayW = w;
              displayH = w / imgAspect;
              offX = 0;
              offY = (h - displayH) / 2;
            } else {
              displayH = h;
              displayW = h * imgAspect;
              offX = (w - displayW) / 2;
              offY = 0;
            }
            return GestureDetector(
              onTapUp: (details) {
                _markOnSharedScreen(
                  details.localPosition,
                  Size(w, h),
                  Size(imgW, imgH),
                );
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(
                      base64Decode(_currentScreenFrame!),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: Text('屏幕加载中...')),
                      ),
                    ),
                  ),
                  ..._guideMarks.map((mark) {
                    final x = (mark['x'] as num).toDouble();
                    final y = (mark['y'] as num).toDouble();
                    return Positioned(
                      left: offX + x * displayW - 14,
                      top: offY + y * displayH - 14,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                        ),
                        child: Center(
                          child: Text(
                            '${mark['order']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      color: Colors.black54,
                      child: Row(
                        children: [
                          const Icon(Icons.circle, color: Colors.red, size: 8),
                          const SizedBox(width: 4),
                          Text(
                            '对方屏幕共享中 · 点击标记位置',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: w < 400 ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final s = context.watch<FontSizeProvider>().scaled;
    final isMe = msg['isMe'] as bool;
    final type = msg['type'] as String? ?? 'text';

    Widget content;
    if (type == 'text') {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          msg['text'] ?? '',
          style: TextStyle(
              fontSize: s(18),
              color: isMe ? Colors.white : Colors.black87),
        ),
      );
    } else if (type == 'tutorial') {
      final tutorial = msg['tutorial'] as Map<String, dynamic>? ?? {};
      content = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TutorialDetailScreen(
                tutorial: Tutorial(
                  id: tutorial['id'] ?? 0,
                  title: tutorial['title'] ?? '',
                  description: tutorial['description'] ?? '',
                  category: '',
                  difficultyLevel: 'beginner',
                  steps: [],
                ),
              ),
            ),
          );
        },
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book,
                      size: 20,
                      color: isMe ? Colors.white70 : AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tutorial['title'] ?? '',
                      style: TextStyle(
                        fontSize: s(16),
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                tutorial['description'] ?? '',
                style: TextStyle(
                  fontSize: s(14),
                  color: isMe ? Colors.white70 : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '点击查看教程 >',
                style: TextStyle(
                  fontSize: s(14),
                  color: isMe ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (type == 'guide_sent') {
      final markCount = msg['markCount'] ?? 0;
      content = Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(Icons.touch_app, size: 32,
                color: isMe ? Colors.white : AppColors.primary),
            const SizedBox(height: 8),
            Text(
              '已发送 $markCount 个引导标记',
              style: TextStyle(
                fontSize: s(16),
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '对方查看图片后将显示引导',
              style: TextStyle(
                fontSize: s(14),
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // screenshot / annotation 类型
      content = GestureDetector(
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
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
  }
}

/// 引导标记脉冲动画组件
class _GuideMarkWidget extends StatefulWidget {
  final int order;

  const _GuideMarkWidget({required this.order});

  @override
  State<_GuideMarkWidget> createState() => _GuideMarkWidgetState();
}

class _GuideMarkWidgetState extends State<_GuideMarkWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 36 * _animation.value,
          height: 36 * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.3),
          ),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: Center(
                child: Text(
                  '${widget.order}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
