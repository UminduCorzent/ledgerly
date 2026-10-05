import 'dart:typed_data';

import 'file_output_native.dart' if (dart.library.js_interop) 'file_output_web.dart' as impl;

/// Saving and sharing generated files (exports, backups).
///
/// On the phone: the system "Save as" dialog and the share sheet.
/// On the web preview: a browser download (sharing isn't available).
class FileOutput {
  const FileOutput._();

  static bool get canShare => impl.canShare;

  /// Returns true when the file was saved (false if the user cancelled).
  static Future<bool> save(Uint8List bytes, String fileName, String mimeType) =>
      impl.saveBytes(bytes, fileName, mimeType);

  /// Returns true when the share sheet completed.
  static Future<bool> share(Uint8List bytes, String fileName, String mimeType, {String? subject}) =>
      impl.shareBytes(bytes, fileName, mimeType, subject: subject);
}
