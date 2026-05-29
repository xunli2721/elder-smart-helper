import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/font_size_provider.dart';
import '../services/tts_service.dart';
import '../models/tutorial.dart';

class TutorialDetailScreen extends StatefulWidget {
  final Tutorial tutorial;
  const TutorialDetailScreen({super.key, required this.tutorial});

  @override
  State<TutorialDetailScreen> createState() => _TutorialDetailScreenState();
}

class _TutorialDetailScreenState extends State<TutorialDetailScreen> {
  int _currentStep = 0;
  bool _isSpeaking = false;
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.init();
    // 读取用户的语速偏好
    if (mounted) {
      final rate = context.read<FontSizeProvider>().speechRate;
      await _tts.setRateByLevel(rate);
    }
  }

  Future<void> _toggleSpeak() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      final step = widget.tutorial.steps[_currentStep];
      final text = '${step.title}。${step.description}';
      // 同步当前语速
      final rate = context.read<FontSizeProvider>().speechRate;
      await _tts.setRateByLevel(rate);
      // 设置完成回调
      _tts.onComplete = () {
        if (mounted) setState(() => _isSpeaking = false);
      };
      setState(() => _isSpeaking = true);
      await _tts.speak(text);
    }
  }

  void _goToStep(int step) {
    // 切换步骤时停止朗读
    _tts.stop();
    setState(() {
      _currentStep = step;
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.tutorial.steps;
    final step = steps[_currentStep];
    final s = context.read<FontSizeProvider>().scaled;

    return Scaffold(
      appBar: AppBar(title: Text(widget.tutorial.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 进度指示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(steps.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentStep ? 24 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: index == _currentStep ? const Color(0xFF4A90E2) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // 步骤编号
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF4A90E2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${step.step}',
                  style: TextStyle(fontSize: s(36), color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 步骤标题 + 朗读按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(fontSize: s(26), fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleSpeak,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isSpeaking ? Colors.orange : const Color(0xFF4A90E2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                      size: 28,
                      color: _isSpeaking ? Colors.white : const Color(0xFF4A90E2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 步骤描述
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app, size: 60, color: Color(0xFF4A90E2)),
                    const SizedBox(height: 16),
                    Text(
                      step.description,
                      style: TextStyle(fontSize: s(22), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 导航按钮
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _goToStep(_currentStep - 1),
                      icon: const Icon(Icons.arrow_back, size: 24),
                      label: Text('上一步', style: TextStyle(fontSize: s(20))),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  flex: _currentStep > 0 ? 1 : 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_currentStep < steps.length - 1) {
                        _goToStep(_currentStep + 1);
                      } else {
                        _showCompleteDialog();
                      }
                    },
                    icon: Icon(_currentStep < steps.length - 1 ? Icons.arrow_forward : Icons.check, size: 24),
                    label: Text(_currentStep < steps.length - 1 ? '下一步' : '完成', style: TextStyle(fontSize: s(20))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCompleteDialog() {
    final s = context.read<FontSizeProvider>().scaled;
    _tts.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('恭喜！', style: TextStyle(fontSize: s(24))),
        content: Text('您已完成「${widget.tutorial.title}」的学习！', style: TextStyle(fontSize: s(20))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('返回', style: TextStyle(fontSize: s(18))),
          ),
        ],
      ),
    );
  }
}