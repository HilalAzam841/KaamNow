import 'dart:typed_data';

import 'file_saver_io.dart' if (dart.library.js_interop) 'file_saver_web.dart' as impl;

/// Saves downloaded bytes as a file: a browser download on the web, the share sheet on phones
/// (so the worker can save it to Files, Drive or send it on WhatsApp).
Future<bool> saveBytes(Uint8List bytes, String filename, String contentType) =>
    impl.saveBytes(bytes, filename, contentType);
