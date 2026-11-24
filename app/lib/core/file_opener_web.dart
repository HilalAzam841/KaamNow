import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

bool openBytes(Uint8List bytes, String contentType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: contentType));
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  return true;
}
