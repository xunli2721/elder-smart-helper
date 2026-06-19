import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:elder_smart_helper/config/app_config.dart';
import 'package:elder_smart_helper/services/api_service.dart';

class SocketService {
  static io.Socket? _socket;
  static int? _currentSessionId;

  static int? get currentSessionId => _currentSessionId;

  static bool get isConnected => _socket != null && _socket!.connected;

  static Future<void> connect({int? userId}) async {
    if (_socket != null && _socket!.connected) {
      // 已连接，仅更新在线状态
      if (userId != null) {
        _socket!.emit('user_online', userId);
      }
      return;
    }

    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('未登录，无法建立连接');
    }

    final completer = Completer<void>();

    _socket = io.io(AppConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      // 通知服务端用户上线
      if (userId != null) {
        _socket!.emit('user_online', userId);
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _socket!.onConnectError((data) {
      debugPrint('Socket connect error: $data');
      if (!completer.isCompleted) {
        completer.completeError(Exception('连接失败: $data'));
      }
    });

    _socket!.onError((data) {
      debugPrint('Socket error: $data');
    });

    _socket!.connect();

    // 10 秒连接超时
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (!completer.isCompleted) {
          _socket?.disconnect();
          _socket = null;
          throw Exception('连接超时');
        }
      },
    );
  }

  static void joinSession(int sessionId) {
    _currentSessionId = sessionId;
    _socket?.emit('join_session', sessionId);
  }

  static void sendScreenshot(int sessionId, String imageData) {
    _socket?.emit('screenshot', {
      'sessionId': sessionId,
      'image': imageData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void sendAnnotation(
    int sessionId,
    Map<String, dynamic> annotation,
  ) {
    _socket?.emit('annotation', {
      'sessionId': sessionId,
      'annotation': annotation,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void sendMessage(int sessionId, String message, String sender) {
    _socket?.emit('message', {
      'sessionId': sessionId,
      'message': message,
      'sender': sender,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void endSession(int sessionId) {
    _socket?.emit('end_session', {'sessionId': sessionId});
    _currentSessionId = null;
  }

  static void onScreenshot(Function(dynamic) callback) {
    _socket?.on('screenshot', callback);
  }

  static void onAnnotation(Function(dynamic) callback) {
    _socket?.on('annotation', callback);
  }

  static void onMessage(Function(dynamic) callback) {
    _socket?.on('message', callback);
  }

  static void onSessionEnded(Function(dynamic) callback) {
    _socket?.on('session_ended', callback);
  }

  static void offMessage() {
    _socket?.off('message');
  }

  static void offScreenshot() {
    _socket?.off('screenshot');
  }

  static void offAnnotation() {
    _socket?.off('annotation');
  }

  static void offSessionEnded() {
    _socket?.off('session_ended');
  }

  static void removeAllListeners() {
    offMessage();
    offScreenshot();
    offAnnotation();
    offSessionEnded();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _currentSessionId = null;
  }
}
