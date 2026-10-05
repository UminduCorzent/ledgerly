import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const bool canShare = false;

/// Browser download of an in-memory file.
Future<bool> saveBytes(Uint8List bytes, String fileName, String mimeType) async {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

Future<bool> shareBytes(Uint8List bytes, String fileName, String mimeType, {String? subject}) async => false;
