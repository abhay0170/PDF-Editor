import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/protect_controller.dart';

enum _ProtectMode { addPassword, removePassword }

class ProtectScreen extends HookConsumerWidget {
  const ProtectScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final mode = useState(_ProtectMode.addPassword);
    final password = useTextEditingController();
    final confirmPassword = useTextEditingController();
    useListenable(password);
    useListenable(confirmPassword);
    final obscure = useState(true);
    final protectState = ref.watch(protectControllerProvider);
    final isProcessing = protectState.value is ToolProcessing;

    ref.listen<AsyncValue<ProtectState>>(protectControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(protectControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(protectControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    final theme = Theme.of(context);
    final document = selectedDocument.value;
    final isAdding = mode.value == _ProtectMode.addPassword;
    final passwordsMismatch =
        isAdding && confirmPassword.text.isNotEmpty && password.text != confirmPassword.text;
    final canSubmit =
        document != null &&
        !isProcessing &&
        password.text.isNotEmpty &&
        (!isAdding || password.text == confirmPassword.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Protect')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: document,
            onSelected: (doc) => selectedDocument.value = doc,
          ),
          const SizedBox(height: Spacing.xxl),
          SegmentedButton<_ProtectMode>(
            segments: const [
              ButtonSegment(value: _ProtectMode.addPassword, label: Text('Add password')),
              ButtonSegment(value: _ProtectMode.removePassword, label: Text('Remove password')),
            ],
            selected: {mode.value},
            onSelectionChanged: (selection) => mode.value = selection.first,
          ),
          const SizedBox(height: Spacing.xxl),
          TextField(
            controller: password,
            obscureText: obscure.value,
            decoration: InputDecoration(
              labelText: isAdding ? 'New password' : 'Current password',
              suffixIcon: IconButton(
                icon: Icon(obscure.value ? AppIcons.eyeOff : AppIcons.eye),
                onPressed: () => obscure.value = !obscure.value,
              ),
            ),
          ),
          if (isAdding) ...[
            const SizedBox(height: Spacing.md),
            TextField(
              controller: confirmPassword,
              obscureText: obscure.value,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                errorText: passwordsMismatch ? 'Passwords don\'t match' : null,
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
              isAdding
                  ? 'Encrypts the PDF itself with AES-256 — it will require this password to open '
                        'in any app, not just this one. The original document is kept unchanged; a '
                        'new, protected copy is added to your library.'
                  : 'Requires the document\'s current password to remove its encryption. A new, '
                        'unprotected copy is added to your library.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canSubmit
            ? () => isAdding
                  ? ref.read(protectControllerProvider.notifier).addPassword(document, password.text)
                  : ref.read(protectControllerProvider.notifier).removePassword(document, password.text)
            : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.lock),
        label: Text(
          isProcessing ? 'Processing…' : (isAdding ? 'Add Password' : 'Remove Password'),
        ),
      ),
    );
  }
}
