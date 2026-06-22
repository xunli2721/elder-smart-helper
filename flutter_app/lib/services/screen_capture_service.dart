import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 屏幕帧数据
class ScreenFrame {
  final String imageBase64;
  final int width;
  final int height;

  const ScreenFrame({
    required this.imageBase64,
    required this.width,
    required this.height,
  });
}

/// 屏幕录制服务（Android 原生 MediaProjection）
class ScreenCaptureService {
  static const _captureChannel =
      MethodChannel('com.eldersmarthelper/screen_capture');
  static const _overlayChannel =
      MethodChannel('com.eldersmarthelper/guide_overlay');
  static const _frameEventChannel =
      EventChannel('com.eldersmarthelper/screen_frames');

  static StreamController<ScreenFrame>? _frameController;
  static StreamSubscription? _frameSubscription;

  /// 屏幕帧流
  static Stream<ScreenFrame>? get frameStream => _frameController?.stream;

  /// 请求开始录屏（弹出系统授权弹窗）
  static Future<bool> startCapture() async {
    try {
      final result =
          await _captureChannel.invokeMethod<bool>('startCapture', {});
      // 开始监听帧流
      _startListening();
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('startCapture error: ${e.message}');
      return false;
    }
  }

  /// 停止录屏
  static Future<void> stopCapture() async {
    try {
      _stopListening();
      await _captureChannel.invokeMethod('stopCapture', {});
    } on PlatformException catch (e) {
      debugPrint('stopCapture error: ${e.message}');
    }
  }

  /// 是否正在录屏
  static Future<bool> isCapturing() async {
    try {
      return await _captureChannel.invokeMethod<bool>('isCapturing') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 是否有悬浮窗权限
  static Future<bool> hasOverlayPermission() async {
    try {
      return await _overlayChannel
              .invokeMethod<bool>('hasOverlayPermission') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// 请求悬浮窗权限
  static Future<void> requestOverlayPermission() async {
    try {
      await _overlayChannel.invokeMethod('requestOverlayPermission', {});
    } on PlatformException catch (e) {
      debugPrint('requestOverlayPermission error: ${e.message}');
    }
  }

  /// 显示系统悬浮窗引导
  static Future<void> showGuideOverlay(List<Map<String, dynamic>> marks) async {
    try {
      await _overlayChannel.invokeMethod('showGuideOverlay', {
        'marks': marks.toString(),
      });
    } on PlatformException catch (e) {
      debugPrint('showGuideOverlay error: ${e.message}');
    }
  }

  /// 隐藏悬浮窗引导
  static Future<void> hideGuideOverlay() async {
    try {
      await _overlayChannel.invokeMethod('hideGuideOverlay', {});
    } on PlatformException catch (e) {
      debugPrint('hideGuideOverlay error: ${e.message}');
    }
  }

  /// 设置确认回调（悬浮窗中点击"我已完成"时触发）
  static void setConfirmCallback(VoidCallback callback) {
    _overlayChannel.setMethodCallHandler((call) async {
      if (call.method == 'onGuideConfirmed') {
        callback();
      }
    });
  }

  static void _startListening() {
    _frameController ??= StreamController<ScreenFrame>.broadcast();
    _frameSubscription?.cancel();
    _frameSubscription =
        _frameEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _frameController?.add(ScreenFrame(
          imageBase64: event['image'] ?? '',
          width: event['width'] ?? 0,
          height: event['height'] ?? 0,
        ));
      }
    });
  }

  static void _stopListening() {
    _frameSubscription?.cancel();
    _frameSubscription = null;
    _frameController?.close();
    _frameController = null;
  }

  /// 释放资源
  static void dispose() {
    _stopListening();
  }
}
