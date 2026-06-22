import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  void Function()? onComplete;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.4); // 慢速，适配老年人
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      print('TTS Error: $msg');
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await init();
    await _tts.stop();
    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  Future<void> setRate(double rate) async {
    await init();
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// 语速档位：慢 0.3 / 中 0.5 / 快 0.7
  Future<void> setRateByLevel(String level) async {
    switch (level) {
      case 'slow':
        await setRate(0.3);
        break;
      case 'medium':
        await setRate(0.5);
        break;
      case 'fast':
        await setRate(0.7);
        break;
      default:
        await setRate(0.4);
    }
  }

  void dispose() {
    _tts.stop();
  }
}