import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

const bool canShare = true;

Future<bool> saveBytes(Uint8List bytes, String fileName, String mimeType) async {
  final path = await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
  return path != null;
}

Future<bool> shareBytes(Uint8List bytes, String fileName, String mimeType, {String? subject}) async {
  final result = await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
    fileNameOverrides: [fileName],
    subject: subject,
  ));
  return result.status == ShareResultStatus.success;
}
