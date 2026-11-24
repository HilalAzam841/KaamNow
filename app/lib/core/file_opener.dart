import 'dart:typed_data';

import 'file_opener_stub.dart' if (dart.library.js_interop) 'file_opener_web.dart' as impl;

/// Opens downloaded bytes (e.g. a PDF) in a new browser tab. Returns false where unsupported.
bool openBytes(Uint8List bytes, String contentType) => impl.openBytes(bytes, contentType);
