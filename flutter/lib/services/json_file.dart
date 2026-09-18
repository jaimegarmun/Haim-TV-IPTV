import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A JSON file stored next to the app database. Writes are serialized and
/// atomic (write to a temp file, then rename) so a crash mid-write never
/// leaves a corrupted file behind.
class JsonFile {
  final String fileName;
  Future<void> _pendingWrite = Future.value();

  JsonFile(this.fileName);

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<Object?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content);
    } catch (e) {
      debugPrint("Failed to read $fileName: $e");
      return null;
    }
  }

  Future<void> write(Object data) {
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        final file = await _file();
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(encoded, flush: true);
        await tmp.rename(file.path);
      } catch (e) {
        debugPrint("Failed to write $fileName: $e");
      }
    });
    return _pendingWrite;
  }
}
