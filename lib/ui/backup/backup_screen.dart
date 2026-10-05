import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format/dates.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/tokens.dart';
import '../../state/backup_store.dart';
import '../../state/txn_filter_store.dart';
import '../export/file_ready_sheet.dart';
import '../widgets/common.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Uint8List _bytesOf(BackupEntry e) => Uint8List.fromList(utf8.encode(e.json));

  Future<void> _backupNow() async {
    final s = AppStrings.of(context);
    setState(() => _busy = true);
    final entry = await context.read<BackupStore>().create();
    if (!mounted) return;
    setState(() => _busy = false);
    if (entry == null) return;
    HapticFeedback.lightImpact();
    showSnack(context, s.backupCreated);
    await showFileReadySheet(context, bytes: _bytesOf(entry), fileName: entry.fileName, mimeType: 'application/json');
  }

  Future<void> _restore(String json) async {
    final s = AppStrings.of(context);
    final ok = await confirmDestructive(
      context,
      title: s.restoreConfirmTitle,
      body: s.restoreConfirmBody,
      action: s.restore,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final outcome = await context.read<BackupStore>().restore(json);
    if (!mounted) return;
    setState(() => _busy = false);
    context.read<TxnFilterStore>().clearFilters();
    switch (outcome) {
      case RestoreOutcome.restored:
        HapticFeedback.lightImpact();
        showSnack(context, s.restored);
      case RestoreOutcome.invalidFile:
        showSnack(context, s.restoreInvalid);
      case RestoreOutcome.failedRolledBack:
        showSnack(context, s.restoreFailed);
    }
  }

  Future<void> _restoreFromFile() async {
    final s = AppStrings.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      showSnack(context, s.restoreInvalid);
      return;
    }
    await _restore(text);
  }

  Future<void> _delete(BackupEntry e) async {
    final s = AppStrings.of(context);
    final ok = await confirmDestructive(context, title: s.deleteBackupTitle, body: s.deleteBackupBody);
    if (!ok || !mounted) return;
    await context.read<BackupStore>().delete(e.id);
    if (mounted) showSnack(context, s.backupDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final store = context.watch<BackupStore>();
    final backups = store.backups;

    return Scaffold(
      appBar: AppTopBar(title: s.backupTitle),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.warnBg, borderRadius: BorderRadius.circular(18)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: c.warn),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.backupPrivacy, style: TextStyle(color: c.warn, height: 1.4))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.backupNow, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(s.backupNowBody, style: TextStyle(color: c.muted)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _backupNow,
                    icon: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.backup_outlined),
                    label: Text(s.backupNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.card),
                side: BorderSide(color: c.line),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
                leading: const Icon(Icons.restore_page_outlined),
                title: Text(s.restoreFromFile, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(s.restoreFromFileBody),
                trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
                onTap: _restoreFromFile,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(s.backupsOnDevice.toUpperCase(),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.muted)),
            ),
            if (backups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(s.backupsEmpty, style: TextStyle(color: c.muted)),
              )
            else
              for (final b in backups)
                Padding(
                  key: ValueKey(b.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SectionCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        Icon(
                          b.kind == BackupKind.safety ? Icons.history_rounded : Icons.inventory_2_outlined,
                          color: c.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullDateTime(b.createdAt), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                [
                                  s.backupSize((b.sizeBytes / 1024).toStringAsFixed(1)),
                                  if (b.kind == BackupKind.safety) s.backupKindSafety,
                                ].join(' · '),
                                style: TextStyle(color: c.muted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, color: c.muted),
                          onSelected: (v) {
                            switch (v) {
                              case 'restore':
                                _restore(b.json);
                              case 'save':
                                showFileReadySheet(
                                  context,
                                  bytes: _bytesOf(b),
                                  fileName: b.fileName,
                                  mimeType: 'application/json',
                                );
                              case 'delete':
                                _delete(b);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'restore', child: Text(s.restore)),
                            PopupMenuItem(value: 'save', child: Text(s.saveCopy)),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(s.delete, style: TextStyle(color: c.expense)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
