import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  static io.Socket? _socket;

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(AppConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
    });
  }

  static void joinSession(int sessionId) {
    _socket?.emit('join_session', sessionId);
  }

  static void sendScreenshot(int sessionId, String imageData) {
    _socket?.emit('screenshot', {
      'sessionId': sessionId,
      'image': imageData,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void sendAnnotation(int sessionId, Map<String, dynamic> annotation) {
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
    removeAllListeners();
    _socket?.disconnect();
    _socket = null;
  }
}
