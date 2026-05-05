import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  final String repoOwner;
  final String repoName;
  final String currentVersion;

  UpdateChecker({
    required this.repoOwner,
    required this.repoName,
    required this.currentVersion,
  });

  factory UpdateChecker.fromCurrentApp({
    String repoOwner = '你的GitHub用户名',
    String repoName = 'FCMBox',
  }) async {
    final info = await PackageInfo.fromPlatform();
    return UpdateChecker(
      repoOwner: repoOwner,
      repoName: repoName,
      currentVersion: info.version,
    );
  }

  /// 从 GitHub Releases 检查最新版本
  Future<UpdateInfo?> check({bool includePrereleases = false}) async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (response.statusCode != 200) return null;

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) return null;

      dynamic latest;
      for (final release in releases) {
        final isPrerelease = release['prerelease'] as bool? ?? false;
        if (isPrerelease && !includePrereleases) continue;
        latest = release;
        break;
      }
      if (latest == null) return null;

      final version = latest['tag_name'] as String? ?? '';
      final name = latest['name'] as String? ?? '';
      final body = latest['body'] as String? ?? '';
      final downloadUrl = latest['html_url'] as String? ?? '';

      final hasUpdate = _compareVersion(version, currentVersion) > 0;
      return UpdateInfo(
        latestVersion: version,
        name: name,
        body: body,
        downloadUrl: downloadUrl,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  int _compareVersion(String v1, String v2) {
    final parts1 = _parseVersion(v1);
    final parts2 = _parseVersion(v2);
    for (int i = 0; i < 3; i++) {
      final cmp = parts1[i].compareTo(parts2[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  List<int> _parseVersion(String version) {
    final cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '').trim();
    final parts = cleaned
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }
}

class UpdateInfo {
  final String latestVersion;
  final String name;
  final String body;
  final String downloadUrl;
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.name,
    required this.body,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}