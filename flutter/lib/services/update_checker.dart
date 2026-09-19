import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_tv/services/json_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_tv/l10n/l10n.dart';

const githubRepo = "jaimegarmun/Haim-TV-IPTV";

class ReleaseInfo {
  final String version;
  final String notes;
  final String pageUrl;

  /// The file for this platform, if the release has one.
  final String? assetUrl;
  final String? assetName;

  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.assetUrl,
    this.assetName,
  });
}

/// Looks for a newer Haim TV release on GitHub and installs it.
class UpdateChecker {
  static final UpdateChecker instance = UpdateChecker._();
  UpdateChecker._();

  static const _channel = MethodChannel("io.github.jaimegarmun.haimtv/updater");
  final _prefs = JsonFile("update_settings.json");

  /// Only ask once per app start, even if the home screen is rebuilt.
  bool _checkedThisSession = false;

  Future<bool> isCheckOnStartEnabled() async {
    final data = await _prefs.read();
    if (data is Map && data["checkOnStart"] is bool) {
      return data["checkOnStart"] as bool;
    }
    return true;
  }

  Future<void> setCheckOnStart(bool enabled) =>
      _prefs.write({"checkOnStart": enabled});

  /// The newer release to offer on start, or null.
  Future<ReleaseInfo?> checkOnStart() async {
    if (_checkedThisSession) return null;
    _checkedThisSession = true;
    if (!await isCheckOnStartEnabled()) return null;
    return checkNow();
  }

  /// The latest release if it is newer than this build, or null. Never
  /// throws: being offline must not bother the user.
  Future<ReleaseInfo?> checkNow() async {
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final release = await _fetchLatest();
      if (release == null) return null;
      return isNewer(release.version, current) ? release : null;
    } catch (e) {
      debugPrint("Update check failed: $e");
      return null;
    }
  }

  Future<ReleaseInfo?> _fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        Uri.parse("https://api.github.com/repos/$githubRepo/releases/latest"),
      );
      request.headers.set(HttpHeaders.userAgentHeader, "HaimTV");
      request.headers.set(HttpHeaders.acceptHeader, "application/vnd.github+json");
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final assets = (json["assets"] as List? ?? []).cast<Map>();
      final asset = assets
          .where((a) => _isAssetForThisPlatform(a["name"] as String? ?? ""))
          .firstOrNull;
      return ReleaseInfo(
        version: (json["tag_name"] as String).replaceFirst(
          RegExp(r"^[vV]"),
          "",
        ),
        notes: (json["body"] as String? ?? "").trim(),
        pageUrl: json["html_url"] as String,
        assetUrl: asset?["browser_download_url"] as String?,
        assetName: asset?["name"] as String?,
      );
    } finally {
      client.close();
    }
  }

  static bool _isAssetForThisPlatform(String name) {
    final lower = name.toLowerCase();
    if (Platform.isAndroid) return lower.endsWith(".apk");
    if (Platform.isWindows) return lower.endsWith("-windows.zip");
    if (Platform.isLinux) return lower.endsWith(".flatpak");
    return false;
  }

  /// Compares dotted versions, e.g. 1.0.10 > 1.0.9.
  static bool isNewer(String candidate, String current) {
    List<int> parse(String v) => v
        .split("+")
        .first
        .split("-")
        .first
        .split(".")
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parse(candidate);
    final b = parse(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Whether the update can be installed from inside the app. Elsewhere
  /// (Linux) the download page is opened instead.
  static bool canInstallInApp(ReleaseInfo release) =>
      release.assetUrl != null && (Platform.isAndroid || Platform.isWindows);

  /// Downloads the release file, reporting progress from 0 to 1 (null when
  /// the size is unknown).
  Future<File> download(
    ReleaseInfo release,
    void Function(double? progress) onProgress,
  ) async {
    final dir = Directory(
      "${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates",
    );
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File(
      "${dir.path}${Platform.pathSeparator}${release.assetName}",
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(release.assetUrl!));
      request.headers.set(HttpHeaders.userAgentHeader, "HaimTV");
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException(
          tr("Download failed (HTTP {code})", {"code": response.statusCode}),
        );
      }
      final total = response.contentLength;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(total > 0 ? received / total : null);
        }
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      client.close();
    }
  }

  /// Hands the downloaded file to the system installer (Android) or
  /// replaces this installation and restarts (Windows).
  Future<void> install(File file) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod("installApk", {"path": file.path});
    } else if (Platform.isWindows) {
      await _installWindows(file);
    }
  }

  /// The Windows build is a portable folder. A detached PowerShell script
  /// waits for this process to exit, copies the new files over the
  /// installation folder and starts the app again.
  Future<void> _installWindows(File zip) async {
    final exe = File(Platform.resolvedExecutable);
    final installDir = exe.parent.path;
    final exeName = exe.uri.pathSegments.last;
    final script = File("${zip.parent.path}\\install-update.ps1");
    String quote(String s) => "'${s.replaceAll("'", "''")}'";
    await script.writeAsString('''
\$ErrorActionPreference = 'Stop'
\$zip = ${quote(zip.path)}
\$installDir = ${quote(installDir)}
\$exeName = ${quote(exeName)}
Wait-Process -Id $pid -ErrorAction SilentlyContinue
\$extract = Join-Path (Split-Path \$zip) 'extracted'
if (Test-Path \$extract) { Remove-Item \$extract -Recurse -Force }
Expand-Archive -Path \$zip -DestinationPath \$extract -Force
# The zip may or may not have a top folder: use the one with the exe.
\$newExe = Get-ChildItem -Path \$extract -Recurse -Filter \$exeName | Select-Object -First 1
if (\$null -eq \$newExe) { \$newExe = Get-ChildItem -Path \$extract -Recurse -Filter '*.exe' | Select-Object -First 1 }
Copy-Item -Path (Join-Path \$newExe.DirectoryName '*') -Destination \$installDir -Recurse -Force
Start-Process -FilePath (Join-Path \$installDir \$newExe.Name) -WorkingDirectory \$installDir
''');
    await Process.start(
      "powershell.exe",
      [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-WindowStyle",
        "Hidden",
        "-File",
        script.path,
      ],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}
