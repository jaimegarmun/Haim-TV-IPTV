import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Windows stores app data under %APPDATA%\<CompanyName>\<ProductName>. The
/// company name changed from "dev.fredol" to "jaimegarmun", so data from
/// older builds is moved to the new folder. Must run before anything opens
/// files there (database, JSON stores).
///
/// Returns the (old, new) folder pair when data was moved, so absolute paths
/// saved inside the data (downloads) can be fixed.
Future<(String, String)?> migrateLegacyWindowsData() async {
  if (!Platform.isWindows) return null;
  try {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    final sep = Platform.pathSeparator;
    final oldDir = Directory("$appData${sep}dev.fredol${sep}Haim TV");
    if (!await oldDir.exists()) return null;
    final newDir = await getApplicationSupportDirectory();
    if (newDir.path.toLowerCase() == oldDir.path.toLowerCase()) return null;
    // path_provider creates the new folder; only take over an empty one.
    if (await newDir.exists()) {
      if (!await newDir.list().isEmpty) return null;
      await newDir.delete();
    }
    await newDir.parent.create(recursive: true);
    await oldDir.rename(newDir.path);
    final oldParent = oldDir.parent;
    if (await oldParent.list().isEmpty) await oldParent.delete();
    return (oldDir.path, newDir.path);
  } catch (e) {
    debugPrint("Could not migrate old data folder: $e");
    return null;
  }
}
