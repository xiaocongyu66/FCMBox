import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fcm_box/l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fcm_box/utils/config.dart'; // 导入配置文件

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  String _backendUrl = '';
  String _authKey = '';
  String _ipAddress = '';
  bool _useHttps = true;

  String _backendTitle = 'The Backend Title';
  String _backendInfo = 'The backend info';
  bool _isConnected = false;
  bool _isLoading = false;
  int? _backendStatusCode;
  bool _deleteOldData = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl = prefs.getString('backend_url') ?? '';
      _authKey = prefs.getString('backend_auth') ?? '';
      _ipAddress = prefs.getString('backend_ip') ?? '';
      _useHttps = prefs.getBool('backend_https') ?? true;
      _backendTitle = prefs.getString('cloud_title') ?? 'The Backend Title';
      _backendInfo = prefs.getString('cloud_version') ?? 'The backend info';
      _isConnected = prefs.getBool('backend_active') ?? false;
      _deleteOldData = prefs.getBool('delete_old_data') ?? false;
      _backendStatusCode = prefs.getInt('backend_status_code');
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', _backendUrl);
    await prefs.setString('backend_auth', _authKey);
    await prefs.setString('backend_ip', _ipAddress);
    await prefs.setBool('backend_https', _useHttps);
    await prefs.setBool('delete_old_data', _deleteOldData);
  }

  void _showConfigSheet() async {
    final localizations = AppLocalizations.of(context);
    // 判断当前是否是预设值，如果不是则当作自定义
    final bool isPreset = _backendUrl == AppConfig.cloudflareDefaultUrl ||
                           _backendUrl == AppConfig.firebaseDefaultUrl;
    String customUrl = isPreset ? '' : _backendUrl;
    bool isCustom = !isPreset;

    String tempPresetUrl = isPreset
        ? _backendUrl
        : AppConfig.cloudflareDefaultUrl; // 默认选中 Cloudflare
    final authController = TextEditingController(text: _authKey);
    final ipController = TextEditingController(text: _ipAddress);
    final customUrlController = TextEditingController(text: customUrl);
    bool tempHttps = _useHttps;
    String deviceName = "Unknown Device";

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        deviceName = androidInfo.model;
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AlertDialog(
              title: Text(
                localizations?.backend_status ?? 'Backend Status',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 预设地址选择
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment<String>(
                              value: AppConfig.cloudflareDefaultUrl,
                              label: const Text('Cloudflare'),
                              icon: Image.asset(
                                'assets/icon/Cloudflare.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            ButtonSegment<String>(
                              value: AppConfig.firebaseDefaultUrl,
                              label: const Text('Firebase'),
                              icon: Image.asset(
                                'assets/icon/Firebase.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ],
                          selected: isCustom ? <String>{} : {tempPresetUrl},
                          onSelectionChanged: (Set<String> newSelection) {
                            HapticFeedback.heavyImpact();
                            setSheetState(() {
                              tempPresetUrl = newSelection.first;
                              isCustom = false;
                              customUrlController.clear();
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 自定义地址开关
                      SwitchListTile(
                        title: Text(localizations?.custom_url ?? 'Custom URL'),
                        subtitle: Text(
                          isCustom
                              ? (localizations?.custom_url_enabled ??
                                  'Custom address enabled')
                              : (localizations?.custom_url_disabled ??
                                  'Using preset address'),
                        ),
                        value: isCustom,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          setSheetState(() {
                            isCustom = val;
                            if (val) {
                              customUrlController.text = _backendUrl.isNotEmpty
                                  ? _backendUrl
                                  : '';
                            } else {
                              tempPresetUrl = AppConfig.cloudflareDefaultUrl;
                              customUrlController.clear();
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),

                      // 自定义 URL 输入框
                      if (isCustom)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            controller: customUrlController,
                            decoration: InputDecoration(
                              labelText: localizations?.custom_url_label ??
                                  'Custom Address',
                              hintText: 'your-worker.workers.dev',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              // 实时更新临时变量，但真正保存是在点击保存时
                            },
                          ),
                        ),

                      const SizedBox(height: 8),

                      // 授权密钥
                      TextField(
                        controller: authController,
                        decoration: InputDecoration(
                          labelText: localizations?.authorization_label ??
                              'Authorization',
                          border: const OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 高级选项
                      ExpansionTile(
                        title: Text(localizations?.advanced_options ??
                            'Advanced options'),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        childrenPadding:
                            const EdgeInsets.only(top: 8, bottom: 8),
                        children: [
                          TextField(
                            controller: ipController,
                            decoration: InputDecoration(
                              labelText: localizations?.ip_address_optional ??
                                  'IP Address (Optional)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: Text(
                                localizations?.use_https ?? 'Use HTTPS'),
                            value: tempHttps,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              setSheetState(() => tempHttps = val);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            deviceName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations?.cancel ?? 'Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      if (isCustom) {
                        _backendUrl = customUrlController.text.trim();
                      } else {
                        _backendUrl = tempPresetUrl;
                      }
                      _authKey = authController.text;
                      _ipAddress = ipController.text;
                      _useHttps = tempHttps;
                    });
                    _saveSettings();
                    Navigator.pop(context);
                    _checkBackend();
                  },
                  child: Text(localizations?.save ?? 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkBackend() async {
    if (_backendUrl.isEmpty) return;

    String cleanUrl = _backendUrl.replaceAll(RegExp(r'^https?://'), '');

    setState(() {
      _isLoading = true;
    });

    final uri = Uri.parse(_useHttps ? 'https://$cleanUrl' : 'http://$cleanUrl');
    Uri targetUri = uri;
    Map<String, String> headers = {};
    if (_authKey.isNotEmpty) {
      headers['Authorization'] = _authKey;
    }

    if (_ipAddress.isNotEmpty) {
      targetUri = uri.replace(host: _ipAddress);
      headers['Host'] = cleanUrl;
    }

    try {
      final response = await http.get(targetUri, headers: headers);
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _backendStatusCode = response.statusCode;
      });
      await prefs.setInt('backend_status_code', response.statusCode);
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        String title =
            document.head?.querySelector('title')?.text ?? 'The Backend Title';
        String info =
            document.body?.querySelector('h1')?.text ?? 'The backend info';

        setState(() {
          _backendTitle = title;
          _backendInfo = info;
          _isConnected = true;
        });

        await prefs.setString('cloud_title', title);
        await prefs.setString('cloud_version', info);
        await prefs.setBool('backend_active', true);

        await _registerToken(targetUri, headers);
      } else {
        throw Exception('Status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Backend check failed: $e');
      setState(() {
        // 发生错误时保留旧标题信息
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerToken(
    Uri baseUri,
    Map<String, String> baseHeaders,
  ) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      String deviceName = "Unknown Device";
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        deviceName = androidInfo.model;
      }

      final body = json.encode({"device": deviceName, "token": token});

      final response = await http.put(
        baseUri,
        headers: {...baseHeaders, 'Content-Type': 'application/json'},
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode != 200 && response.statusCode != 204) {
        Fluttertoast.showToast(
          msg:
              '${AppLocalizations.of(context)?.token_registration_failed ?? 'Token registration failed'}: ${response.statusCode}',
        );
      } else {
        Fluttertoast.showToast(
          msg:
              AppLocalizations.of(context)?.token_registration_success ??
              'Token registration success',
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg:
            '${AppLocalizations.of(context)?.token_registration_error ?? 'Token registration error'}: $e',
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.cloud_appbar_title ?? 'Cloud'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: _isConnected
                  ? Icon(
                      Icons.cloud_done,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    )
                  : Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              _backendTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _backendInfo,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 40),

          ListTile(
            leading: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (_isConnected
                    ? const Icon(Icons.check)
                    : const Icon(Icons.close)),
            title: Text(
              localizations?.backend_status ?? 'Backend Status',
            ),
            subtitle: Text(
              _backendStatusCode != null
                  ? 'HTTP $_backendStatusCode'
                  : 'None',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: _showConfigSheet,
          ),

          ListTile(
            leading: const Icon(Icons.code),
            title: Text(
              localizations?.check_code_sample ?? 'View a code sample',
            ),
            onTap: () {
              _launchUrl(AppConfig.codeSampleUrl);
            },
          ),

          SwitchListTile(
            title: Text(
              localizations?.delete_old_data ??
                  'Delete old data after update',
            ),
            value: _deleteOldData,
            onChanged: (val) async {
              HapticFeedback.heavyImpact();
              setState(() => _deleteOldData = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('delete_old_data', val);
            },
          ),
        ],
      ),
    );
  }
}