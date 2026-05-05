import 'package:flutter/material.dart';
import 'package:fcm_box/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/update_checker.dart';
import '../utils/config.dart'; // 导入统一配置文件

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';
  UpdateInfo? _updateInfo;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkUpdate();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version.isNotEmpty
          ? packageInfo.version
          : AppConfig.appVersion; // 回退到配置文件中的版本
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    // UpdateChecker.fromCurrentApp 已改为无参静态方法，从 AppConfig 读取配置
    final checker = await UpdateChecker.fromCurrentApp();
    final info = await checker.check();
    setState(() {
      _updateInfo = info;
      _checkingUpdate = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        Fluttertoast.showToast(
          // 修复：could_not_launch 是方法而非 getter，需要传入 url 参数
          msg: AppLocalizations.of(context)?.could_not_launch(url) ??
              'Could not launch $url',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.about ?? 'About'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),
          Center(
            child: Image.asset(
              'assets/icon/mode_heat.png',
              width: 96,
              height: 96,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              AppLocalizations.of(context)?.app_title ?? AppConfig.appTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          if (_version.isNotEmpty)
            Center(
              child: Text(
                'Version $_version',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          // 更新提示
          if (_updateInfo?.hasUpdate == true) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context)?.update_available ??
                            '有新版本可用: ${_updateInfo?.latestVersion ?? ""}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () {
                          if (_updateInfo?.downloadUrl != null) {
                            _launchUrl(_updateInfo!.downloadUrl);
                          }
                        },
                        child: Text(
                          AppLocalizations.of(context)?.download_update ??
                              '下载更新',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_checkingUpdate)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 40),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(
              AppLocalizations.of(context)?.github_repo ?? 'GitHub Repository',
            ),
            subtitle: Text(AppConfig.repoUrl), // 使用配置中的仓库 URL
            onTap: () {
              _launchUrl(AppConfig.repoUrl);
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: Text(
              AppLocalizations.of(context)?.view_documentation ??
                  'View the Documentation',
            ),
            subtitle: Text(AppConfig.documentationUrl),
            onTap: () {
              _launchUrl(AppConfig.documentationUrl);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(
              AppLocalizations.of(context)?.report_issue ?? 'Report an Issue',
            ),
            onTap: () {
              _launchUrl(AppConfig.issuesUrl);
            },
          ),
        ],
      ),
    );
  }
}