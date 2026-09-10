import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../../../pdf/pdf_providers.dart';
import '../../../../pdf/signature/signature_background_removal.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/sign_controller.dart';
import 'widgets/signature_pad.dart';

/// Signature width as a fraction of the page — fixed rather than resizable
/// to keep the placement interaction to a single, well-understood gesture
/// (drag to reposition).
const double _signatureRelativeWidth = 0.32;

enum _SignatureSource { draw, upload }

class SignScreen extends HookConsumerWidget {
  const SignScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final pageNumber = useState(1);
    final pagePreviewBytes = useState<Uint8List?>(null);
    final pageAspect = useState<double?>(null);
    final relativeX = useState(0.55);
    final relativeY = useState(0.78);
    final isDraggingSignature = useState(false);

    final padController = useMemoized(SignaturePadController.new);
    useEffect(() => padController.dispose, [padController]);
    final drawnSignature = useValueListenable(padController.previewPng);
    final isDrawingSignature = useValueListenable(padController.isDrawing);

    final signatureSource = useState(_SignatureSource.draw);
    final uploadedSignature = useState<Uint8List?>(null);
    final isProcessingUpload = useState(false);
    final uploadError = useState<String?>(null);
    final signaturePreview = signatureSource.value == _SignatureSource.upload
        ? uploadedSignature.value
        : drawnSignature;

    Future<void> pickSignaturePhoto() async {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;

      uploadError.value = null;
      isProcessingUpload.value = true;
      try {
        final bytes = await file.readAsBytes();
        final processed = await compute(removeSignatureBackground, bytes);
        uploadedSignature.value = processed;
      } catch (_) {
        uploadError.value = 'Could not process that photo. Try a clearer image of the signature.';
      } finally {
        isProcessingUpload.value = false;
      }
    }

    final isProcessing = ref.watch(signControllerProvider.select((s) => s.value is ToolProcessing));

    useEffect(() {
      pageNumber.value = selectedDocument.value?.pageCount ?? 1;
      return null;
    }, [selectedDocument.value]);

    useEffect(() {
      final document = selectedDocument.value;
      if (document == null) {
        pagePreviewBytes.value = null;
        return null;
      }
      var cancelled = false;
      pagePreviewBytes.value = null;
      ref.read(pdfEngineProvider).renderPageAtScale(document.path, pageNumber: pageNumber.value, scale: 1.0).then((
        bytes,
      ) {
        if (!cancelled) pagePreviewBytes.value = bytes;
      });
      return () => cancelled = true;
    }, [selectedDocument.value, pageNumber.value]);

    useEffect(() {
      final bytes = pagePreviewBytes.value;
      if (bytes == null) {
        pageAspect.value = null;
        return null;
      }
      var cancelled = false;
      ui.instantiateImageCodec(bytes).then((codec) => codec.getNextFrame()).then((frame) {
        if (!cancelled) pageAspect.value = frame.image.width / frame.image.height;
        frame.image.dispose();
      });
      return () => cancelled = true;
    }, [pagePreviewBytes.value]);

    ref.listen<AsyncValue<SignState>>(signControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(signControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(signControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    void runSign() {
      final document = selectedDocument.value;
      final signatureBytes = signaturePreview;
      if (document == null || signatureBytes == null) return;
      ref
          .read(signControllerProvider.notifier)
          .sign(
            document,
            pageNumber: pageNumber.value,
            signatureImageBytes: signatureBytes,
            relativeX: relativeX.value,
            relativeY: relativeY.value,
            relativeWidth: _signatureRelativeWidth,
          );
    }

    final theme = Theme.of(context);
    final document = selectedDocument.value;
    final canSign = document != null && signaturePreview != null && !isProcessing;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign PDF')),
      body: ListView(
        // While dragging the signature, the list must not also interpret the
        // same vertical finger movement as a scroll — GestureDetector's pan
        // and the list's scroll recognizer would otherwise compete for the
        // same pointer, and the list tends to win vertical movement.
        physics: isDraggingSignature.value || isDrawingSignature
            ? const NeverScrollableScrollPhysics()
            : null,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: document,
            onSelected: (doc) => selectedDocument.value = doc,
          ),
          if (document != null) ...[
            const SizedBox(height: Spacing.sectionSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page', style: theme.textTheme.titleLarge),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(AppIcons.chevronLeft),
                      onPressed: pageNumber.value > 1 ? () => pageNumber.value -= 1 : null,
                    ),
                    Text('${pageNumber.value} of ${document.pageCount}', style: theme.textTheme.bodyLarge),
                    IconButton(
                      icon: Icon(AppIcons.chevronRight),
                      onPressed: pageNumber.value < document.pageCount ? () => pageNumber.value += 1 : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Spacing.sectionSpacing),
            Text('Signature', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            SegmentedButton<_SignatureSource>(
              segments: const [
                ButtonSegment(value: _SignatureSource.draw, label: Text('Draw')),
                ButtonSegment(value: _SignatureSource.upload, label: Text('Upload photo')),
              ],
              selected: {signatureSource.value},
              onSelectionChanged: (selection) => signatureSource.value = selection.first,
            ),
            const SizedBox(height: Spacing.md),
            if (signatureSource.value == _SignatureSource.draw) ...[
              Container(
                height: 180,
                decoration: BoxDecoration(
                  // Fixed white "paper" regardless of app theme — the ink is
                  // always drawn black (see _SignaturePainter) since it's
                  // composited onto a real page later, so the drawing
                  // surface needs to stay light for the ink to stay visible
                  // in dark mode too.
                  color: Colors.white,
                  borderRadius: Radii.mediumRadius,
                  border: Border.all(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: SignaturePad(controller: padController),
              ),
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: padController.clear, child: const Text('Clear')),
              ),
            ] else ...[
              Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Same fixed white "paper" reasoning as the draw-mode pad
                  // above — the uploaded signature's ink is typically dark,
                  // so it needs a light background to stay visible in dark
                  // mode.
                  color: Colors.white,
                  borderRadius: Radii.mediumRadius,
                  border: Border.all(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: isProcessingUpload.value
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : uploadedSignature.value != null
                    ? Padding(
                        padding: const EdgeInsets.all(Spacing.md),
                        child: Image.memory(uploadedSignature.value!, fit: BoxFit.contain),
                      )
                    : Text(
                        'No photo selected',
                        // Fixed dark color, not theme.textTheme — this text
                        // sits on the fixed-white "paper" background above,
                        // not the theme surface, so it needs contrast
                        // against white specifically in both app themes.
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
              ),
              if (uploadError.value != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  uploadError.value!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: Spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: isProcessingUpload.value ? null : pickSignaturePhoto,
                    icon: Icon(AppIcons.image, size: 18),
                    label: Text(uploadedSignature.value == null ? 'Choose a photo' : 'Choose a different photo'),
                  ),
                  if (uploadedSignature.value != null)
                    TextButton(
                      onPressed: () => uploadedSignature.value = null,
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Works best with a signature signed in dark ink on light paper — the light background is removed automatically.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (signaturePreview != null && pagePreviewBytes.value != null && pageAspect.value != null) ...[
              const SizedBox(height: Spacing.sectionSpacing),
              Text('Position on page', style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.sm),
              Text(
                'Drag the signature to place it.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Spacing.md),
              ClipRRect(
                borderRadius: Radii.mediumRadius,
                child: AspectRatio(
                  aspectRatio: pageAspect.value!,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boxWidth = constraints.maxWidth;
                      final boxHeight = constraints.maxHeight;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.memory(pagePreviewBytes.value!, fit: BoxFit.fill),
                          ),
                          Positioned(
                            left: relativeX.value * boxWidth,
                            top: relativeY.value * boxHeight,
                            width: _signatureRelativeWidth * boxWidth,
                            child: Listener(
                              // Raw pointer events, not a GestureRecognizer —
                              // this deliberately sidesteps the gesture arena
                              // so the enclosing ListView's scroll recognizer
                              // can never steal a vertical drag.
                              onPointerDown: (_) => isDraggingSignature.value = true,
                              onPointerUp: (_) => isDraggingSignature.value = false,
                              onPointerCancel: (_) => isDraggingSignature.value = false,
                              onPointerMove: (event) {
                                relativeX.value = (relativeX.value + event.delta.dx / boxWidth).clamp(
                                  0.0,
                                  1.0 - _signatureRelativeWidth,
                                );
                                relativeY.value = (relativeY.value + event.delta.dy / boxHeight).clamp(0.0, 0.95);
                              },
                              child: Image.memory(signaturePreview),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: Radii.mediumRadius,
              ),
              child: Text(
                'The result is recreated as images — text won’t be selectable or searchable.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canSign ? runSign : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.sign),
        label: Text(isProcessing ? 'Signing…' : 'Sign'),
      ),
    );
  }
}
