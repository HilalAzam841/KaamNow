import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<bool> saveBytes(Uint8List bytes, String filename, String contentType) async {
  final result = await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: contentType, name: filename)],
    fileNameOverrides: [filename],
  ));
  return result.status != ShareResultStatus.unavailable;
}
