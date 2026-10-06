import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/platform/file_output.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../state/lock_store.dart';
import '../widgets/common.dart';

/// "Your file is ready" → Save to device (Download on the web) or Share.
Future<void> showFileReadySheet(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final s = AppStrings.of(ctx);
      final c = ctx.colors;
      final kb = (bytes.length / 1024).toStringAsFixed(bytes.length < 10240 ? 1 : 0);

      Future<void> run(Future<bool> Function() action, {bool saved = false}) async {
        final messenger = ScaffoldMessenger.of(ctx);
        final nav = Navigator.of(ctx);
        final lock = ctx.read<LockStore>();
        bool ok;
        try {
          // Save dialogs and the share sheet leave the app; don't lock on return.
          ok = await lock.runExternal(action);
        } catch (_) {
          ok = false;
          messenger.showSnackBar(SnackBar(content: Text(s.fileFailed)));
        }
        if (!ok) return;
        HapticFeedback.lightImpact();
        nav.pop();
        if (saved) messenger.showSnackBar(SnackBar(content: Text(s.fileSaved)));
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.fileReady, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SectionCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(s.backupSize(kb), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => run(() => FileOutput.save(bytes, fileName, mimeType), saved: true),
                icon: Icon(FileOutput.canShare ? Icons.save_alt_rounded : Icons.download_rounded),
                label: Text(FileOutput.canShare ? s.saveToDevice : s.download),
              ),
              if (FileOutput.canShare) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => run(() => FileOutput.share(bytes, fileName, mimeType, subject: fileName)),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(s.shareFile),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
