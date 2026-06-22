import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 标注工具类型
enum AnnotationTool { pen, circle, arrow, text, guide }

/// 引导标记数据
class GuideMarkData {
  final double ratioX; // 0.0~1.0 相对图片宽度
  final double ratioY; // 0.0~1.0 相对图片高度
  final int order;
  final String? text;

  const GuideMarkData({
    required this.ratioX,
    required this.ratioY,
    required this.order,
    this.text,
  });
}

/// 单条标注数据
class AnnotationItem {
  final AnnotationTool tool;
  final List<Offset> points;
  final Color color;
  final String? text;

  const AnnotationItem({
    required this.tool,
    required this.points,
    required this.color,
    this.text,
  });
}

/// 标注画布组件
class AnnotationCanvas extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(
    Uint8List annotatedImageBytes, {
    List<GuideMarkData>? guideMarks,
  }) onComplete;

  const AnnotationCanvas({
    super.key,
    required this.imageBytes,
    required this.onComplete,
  });

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _bgImage;
  AnnotationTool _currentTool = AnnotationTool.pen;
  Color _currentColor = Colors.red;
  final List<AnnotationItem> _items = [];
  final List<GuideMarkData> _guideMarks = [];
  List<Offset> _currentPoints = [];
  bool _isDrawing = false;

  // 文字输入
  Offset? _textPosition;
  final _textController = TextEditingController();

  // 缩放/平移
  double _scale = 1.0;
  double _prevScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _prevOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() {
        _bgImage = frame.image;
      });
    }
  }

  @override
  void dispose() {
    _bgImage?.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_currentTool == AnnotationTool.text) {
      _showTextInput(details.localPosition);
      return;
    }
    if (_currentTool == AnnotationTool.guide) {
      _addGuideMark(details.localPosition);
      return;
    }
    setState(() {
      _isDrawing = true;
      _currentPoints = [details.localPosition];
    });
  }

  void _addGuideMark(Offset position) {
    if (_bgImage == null) return;
    // 计算相对图片的比例坐标
    final renderBox =
        _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final ratioX = (position.dx / size.width).clamp(0.0, 1.0);
    final ratioY = (position.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _guideMarks.add(GuideMarkData(
        ratioX: ratioX,
        ratioY: ratioY,
        order: _guideMarks.length + 1,
      ));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _currentPoints.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _isDrawing = false;
      if (_currentPoints.isNotEmpty) {
        _items.add(AnnotationItem(
          tool: _currentTool,
          points: List.from(_currentPoints),
          color: _currentColor,
        ));
        _currentPoints = [];
      }
    });
  }

  void _showTextInput(Offset position) {
    _textController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入标注文字'),
        content: TextField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入文字'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  _items.add(AnnotationItem(
                    tool: AnnotationTool.text,
                    points: [position],
                    color: _currentColor,
                    text: text,
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_items.isNotEmpty) {
      setState(() => _items.removeLast());
    }
  }

  void _clear() {
    setState(() => _items.clear());
  }

  Future<void> _save() async {
    try {
      RenderRepaintBoundary boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        widget.onComplete(
          byteData.buffer.asUint8List(),
          guideMarks: _guideMarks.isNotEmpty ? _guideMarks : null,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('标注保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text('标注', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _undo,
            tooltip: '撤销',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clear,
            tooltip: '清除',
          ),
          TextButton(
            onPressed: _save,
            child: const Text('发送', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 画布区域
          Expanded(
            child: GestureDetector(
              onScaleStart: (details) {
                _prevScale = _scale;
                _prevOffset = _offset;
                if (details.pointerCount == 1) {
                  _onPanStart(DragStartDetails(localPosition: details.localFocalPoint));
                }
              },
              onScaleUpdate: (details) {
                if (details.pointerCount > 1) {
                  // 双指缩放/平移
                  setState(() {
                    _scale = (_prevScale * details.scale).clamp(0.5, 3.0);
                    _offset = _prevOffset + (details.focalPoint - details.localFocalPoint);
                  });
                } else {
                  _onPanUpdate(DragUpdateDetails(localPosition: details.localFocalPoint, globalPosition: details.focalPoint));
                }
              },
              onScaleEnd: (details) {
                if (_isDrawing) {
                  _onPanEnd(DragEndDetails());
                }
              },
              child: RepaintBoundary(
                key: _repaintKey,
                child: CustomPaint(
                  painter: _AnnotationPainter(
                    image: _bgImage,
                    items: _items,
                    guideMarks: _guideMarks,
                    currentPoints: _currentPoints,
                    currentTool: _currentTool,
                    currentColor: _currentColor,
                    scale: _scale,
                    offset: _offset,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          // 工具栏
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 工具选择
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(AnnotationTool.pen, Icons.edit, '画笔'),
                _toolButton(AnnotationTool.circle, Icons.circle_outlined, '圆形'),
                _toolButton(AnnotationTool.arrow, Icons.arrow_right_alt, '箭头'),
                _toolButton(AnnotationTool.text, Icons.text_fields, '文字'),
                _toolButton(AnnotationTool.guide, Icons.touch_app, '标记'),
              ],
            ),
            const SizedBox(height: 8),
            // 颜色选择
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _colorButton(Colors.red),
                const SizedBox(width: 16),
                _colorButton(Colors.blue),
                const SizedBox(width: 16),
                _colorButton(Colors.green),
                const SizedBox(width: 16),
                _colorButton(Colors.yellow),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(AnnotationTool tool, IconData icon, String label) {
    final isSelected = _currentTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _currentTool = tool),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 28),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
          )),
        ],
      ),
    );
  }

  Widget _colorButton(Color color) {
    final isSelected = _currentColor == color;
    return GestureDetector(
      onTap: () => setState(() => _currentColor = color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final ui.Image? image;
  final List<AnnotationItem> items;
  final List<GuideMarkData> guideMarks;
  final List<Offset> currentPoints;
  final AnnotationTool currentTool;
  final Color currentColor;
  final double scale;
  final Offset offset;

  _AnnotationPainter({
    required this.image,
    required this.items,
    required this.guideMarks,
    required this.currentPoints,
    required this.currentTool,
    required this.currentColor,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制背景图
    if (image != null) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(scale);

      final src = Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(image!, src, dst, Paint());
      canvas.restore();
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.grey[800]!);
    }

    // 绘制已完成的标注
    for (final item in items) {
      _drawItem(canvas, size, item);
    }

    // 绘制引导标记
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    for (final mark in guideMarks) {
      _drawGuideMark(canvas, size, mark);
    }
    canvas.restore();

    // 绘制当前正在画的标注
    if (currentPoints.isNotEmpty) {
      _drawCurrent(canvas, size);
    }
  }

  void _drawItem(Canvas canvas, Size size, AnnotationItem item) {
    final paint = Paint()
      ..color = item.color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    switch (item.tool) {
      case AnnotationTool.pen:
        _drawPath(canvas, item.points, paint);
        break;
      case AnnotationTool.circle:
        _drawCircle(canvas, item.points, paint);
        break;
      case AnnotationTool.arrow:
        _drawArrow(canvas, item.points, paint);
        break;
      case AnnotationTool.guide:
        break; // 引导标记单独绘制
      case AnnotationTool.text:
        _drawText(canvas, item.points.first, item.text ?? '', item.color);
        break;
    }

    canvas.restore();
  }

  void _drawCurrent(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    switch (currentTool) {
      case AnnotationTool.pen:
        _drawPath(canvas, currentPoints, paint);
        break;
      case AnnotationTool.circle:
        if (currentPoints.length >= 2) {
          _drawCircle(canvas, currentPoints, paint);
        }
        break;
      case AnnotationTool.arrow:
        if (currentPoints.length >= 2) {
          _drawArrow(canvas, currentPoints, paint);
        }
        break;
      default:
        break;
    }

    canvas.restore();
  }

  void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawCircle(Canvas canvas, List<Offset> points, Paint paint) {
    final start = points.first;
    final end = points.last;
    final rect = Rect.fromPoints(start, end);
    canvas.drawOval(rect, paint);
  }

  void _drawArrow(Canvas canvas, List<Offset> points, Paint paint) {
    final start = points.first;
    final end = points.last;

    canvas.drawLine(start, end, paint);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = atan2(dy, dx);
    const arrowAngle = pi / 6;
    const arrowLength = 20.0;

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowLength * cos(angle - arrowAngle),
        end.dy - arrowLength * sin(angle - arrowAngle),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowLength * cos(angle + arrowAngle),
        end.dy - arrowLength * sin(angle + arrowAngle),
      );
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, Offset position, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawGuideMark(Canvas canvas, Size size, GuideMarkData mark) {
    final x = mark.ratioX * size.width;
    final y = mark.ratioY * size.height;
    final center = Offset(x, y);

    // 外圈脉冲效果（半透明大圆）
    canvas.drawCircle(center, 28, Paint()
      ..color = Colors.red.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill);

    // 内圈
    canvas.drawCircle(center, 18, Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill);

    // 边框
    canvas.drawCircle(center, 18, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    // 序号文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${mark.order}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.items.length != items.length ||
        oldDelegate.guideMarks.length != guideMarks.length ||
        oldDelegate.currentPoints.length != currentPoints.length ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.image != image;
  }
}