import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image/image.dart' as img;

/// Full-screen crop editor for a single scanned page photo. Not a scrolling
/// context (unlike the tool screens), so plain [GestureDetector.onPanUpdate]
/// is safe here — there's no ancestor `Scrollable` to lose the gesture
/// arena to. Returns the cropped PNG bytes via [Navigator.pop], or null if
/// the user cancels.
class CropPageScreen extends HookWidget {
  const CropPageScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    final image = useState<ui.Image?>(null);

    useEffect(() {
      var cancelled = false;
      ui.instantiateImageCodec(imageBytes).then((codec) => codec.getNextFrame()).then((frame) {
        if (!cancelled) image.value = frame.image;
      });
      return () => cancelled = true;
    }, [imageBytes]);

    // Crop rectangle in fractional coordinates (0-1 of the displayed
    // image), so it stays correct regardless of the actual render size.
    // Margin is kept well clear of the screen edges (not just a thin 5%)
    // since corner handles that close to the edge fall inside Android's
    // system back-gesture zone on gesture-navigation devices, making them
    // hard to grab — found by dragging the default handles on a real phone.
    final rect = useState(const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8));
    final isCropping = useState(false);

    final loadedImage = image.value;
    if (loadedImage == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<void> confirmCrop() async {
      isCropping.value = true;
      try {
        final cropped = await _cropImage(imageBytes, rect.value);
        if (context.mounted) Navigator.of(context).pop(cropped);
      } catch (_) {
        isCropping.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not crop this photo.')));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop'),
        actions: [
          TextButton(
            onPressed: isCropping.value ? null : confirmCrop,
            child: isCropping.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: loadedImage.width / loadedImage.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  Positioned.fill(child: Image.memory(imageBytes, fit: BoxFit.fill)),
                  _CropOverlay(
                    rect: rect.value,
                    boxSize: boxSize,
                    onChanged: (newRect) => rect.value = newRect,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<Uint8List> _cropImage(Uint8List sourceBytes, Rect fractionalRect) async {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Could not read this image.');
  }
  final x = (fractionalRect.left * decoded.width).round().clamp(0, decoded.width - 1);
  final y = (fractionalRect.top * decoded.height).round().clamp(0, decoded.height - 1);
  final width = (fractionalRect.width * decoded.width).round().clamp(1, decoded.width - x);
  final height = (fractionalRect.height * decoded.height).round().clamp(1, decoded.height - y);
  final cropped = img.copyCrop(decoded, x: x, y: y, width: width, height: height);
  return Uint8List.fromList(img.encodePng(cropped));
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CropOverlay extends StatelessWidget {
  const _CropOverlay({required this.rect, required this.boxSize, required this.onChanged});

  final Rect rect;
  final Size boxSize;
  final ValueChanged<Rect> onChanged;

  static const double _minFractionalSize = 0.1;

  Rect _clamp(Rect r) {
    final left = r.left.clamp(0.0, 1.0 - _minFractionalSize);
    final top = r.top.clamp(0.0, 1.0 - _minFractionalSize);
    final right = r.right.clamp(left + _minFractionalSize, 1.0);
    final bottom = r.bottom.clamp(top + _minFractionalSize, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _moveWhole(Offset fractionalDelta) {
    var moved = rect.shift(fractionalDelta);
    if (moved.left < 0) moved = moved.shift(Offset(-moved.left, 0));
    if (moved.top < 0) moved = moved.shift(Offset(0, -moved.top));
    if (moved.right > 1) moved = moved.shift(Offset(1 - moved.right, 0));
    if (moved.bottom > 1) moved = moved.shift(Offset(0, 1 - moved.bottom));
    onChanged(moved);
  }

  void _resizeCorner(_Corner corner, Offset fractionalDelta) {
    var left = rect.left;
    var top = rect.top;
    var right = rect.right;
    var bottom = rect.bottom;
    switch (corner) {
      case _Corner.topLeft:
        left += fractionalDelta.dx;
        top += fractionalDelta.dy;
      case _Corner.topRight:
        right += fractionalDelta.dx;
        top += fractionalDelta.dy;
      case _Corner.bottomLeft:
        left += fractionalDelta.dx;
        bottom += fractionalDelta.dy;
      case _Corner.bottomRight:
        right += fractionalDelta.dx;
        bottom += fractionalDelta.dy;
    }
    onChanged(_clamp(Rect.fromLTRB(left, top, right, bottom)));
  }

  @override
  Widget build(BuildContext context) {
    final pixelRect = Rect.fromLTWH(
      rect.left * boxSize.width,
      rect.top * boxSize.height,
      rect.width * boxSize.width,
      rect.height * boxSize.height,
    );
    final barrierColor = Colors.black.withValues(alpha: 0.55);

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: boxSize.width,
          height: pixelRect.top,
          child: ColoredBox(color: barrierColor),
        ),
        Positioned(
          left: 0,
          top: pixelRect.bottom,
          width: boxSize.width,
          height: boxSize.height - pixelRect.bottom,
          child: ColoredBox(color: barrierColor),
        ),
        Positioned(
          left: 0,
          top: pixelRect.top,
          width: pixelRect.left,
          height: pixelRect.height,
          child: ColoredBox(color: barrierColor),
        ),
        Positioned(
          left: pixelRect.right,
          top: pixelRect.top,
          width: boxSize.width - pixelRect.right,
          height: pixelRect.height,
          child: ColoredBox(color: barrierColor),
        ),
        Positioned(
          left: pixelRect.left,
          top: pixelRect.top,
          width: pixelRect.width,
          height: pixelRect.height,
          child: GestureDetector(
            onPanUpdate: (details) => _moveWhole(
              Offset(details.delta.dx / boxSize.width, details.delta.dy / boxSize.height),
            ),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
            ),
          ),
        ),
        for (final corner in _Corner.values)
          _CornerHandle(
            corner: corner,
            pixelRect: pixelRect,
            onDrag: (delta) => _resizeCorner(
              corner,
              Offset(delta.dx / boxSize.width, delta.dy / boxSize.height),
            ),
          ),
      ],
    );
  }
}

class _CornerHandle extends StatelessWidget {
  const _CornerHandle({required this.corner, required this.pixelRect, required this.onDrag});

  final _Corner corner;
  final Rect pixelRect;
  final ValueChanged<Offset> onDrag;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final double left;
    final double top;
    switch (corner) {
      case _Corner.topLeft:
        left = pixelRect.left - _size / 2;
        top = pixelRect.top - _size / 2;
      case _Corner.topRight:
        left = pixelRect.right - _size / 2;
        top = pixelRect.top - _size / 2;
      case _Corner.bottomLeft:
        left = pixelRect.left - _size / 2;
        top = pixelRect.bottom - _size / 2;
      case _Corner.bottomRight:
        left = pixelRect.right - _size / 2;
        top = pixelRect.bottom - _size / 2;
    }
    return Positioned(
      left: left,
      top: top,
      width: _size,
      height: _size,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26),
          ),
        ),
      ),
    );
  }
}
