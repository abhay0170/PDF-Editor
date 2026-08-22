import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Owns the drawn strokes and exposes a debounced [previewPng] — kept
/// outside the widget tree so callers (the sign screen) can read/clear/export
/// without threading state through a parent rebuild. Re-exporting on every
/// pointer-move event would mean rasterizing dozens of times a second, so
/// this waits until drawing has paused for a moment.
class SignaturePadController {
  SignaturePadController() {
    strokes.addListener(_scheduleExport);
  }

  final GlobalKey repaintKey = GlobalKey();
  final ValueNotifier<List<List<Offset>>> strokes = ValueNotifier(const []);
  final ValueNotifier<Uint8List?> previewPng = ValueNotifier(null);

  /// True while a finger is actively drawing a stroke — callers use this to
  /// disable an enclosing scrollable's physics for the duration (see
  /// [SignaturePad]'s doc comment for why).
  final ValueNotifier<bool> isDrawing = ValueNotifier(false);
  Timer? _debounce;

  bool get isEmpty => strokes.value.isEmpty;

  void clear() => strokes.value = const [];

  void _scheduleExport() {
    _debounce?.cancel();
    if (strokes.value.isEmpty) {
      previewPng.value = null;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      previewPng.value = await _exportPng();
    });
  }

  /// Rasterizes the current strokes to a transparent-background PNG, or null
  /// if nothing has been drawn yet.
  Future<Uint8List?> _exportPng() async {
    if (isEmpty) return null;
    final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.0);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void dispose() {
    _debounce?.cancel();
    strokes.removeListener(_scheduleExport);
    strokes.dispose();
    previewPng.dispose();
    isDrawing.dispose();
  }
}

/// A finger-drawn signature canvas. Strokes are captured with a transparent
/// background so [SignaturePadController.exportPng] produces an image that
/// composites cleanly onto a page.
///
/// Uses raw [Listener] pointer callbacks rather than [GestureDetector]'s
/// pan recognizer: when this pad sits inside a scrolling list (as it does on
/// the sign screen), a `PanGestureRecognizer` loses the gesture arena to the
/// list's own vertical-drag recognizer, so vertical/diagonal strokes never
/// register — only horizontal ones do. This is the same failure mode already
/// found and fixed for the signature-placement drag handle on that screen.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller});

  final SignaturePadController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<List<Offset>>>(
      valueListenable: controller.strokes,
      builder: (context, strokes, _) {
        return Listener(
          onPointerDown: (event) {
            controller.isDrawing.value = true;
            controller.strokes.value = [...strokes, [event.localPosition]];
          },
          onPointerMove: (event) {
            final current = controller.strokes.value;
            final updated = [...current];
            updated[updated.length - 1] = [...updated.last, event.localPosition];
            controller.strokes.value = updated;
          },
          onPointerUp: (_) => controller.isDrawing.value = false,
          onPointerCancel: (_) => controller.isDrawing.value = false,
          child: RepaintBoundary(
            key: controller.repaintKey,
            child: CustomPaint(
              painter: _SignaturePainter(strokes),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => oldDelegate.strokes != strokes;
}
