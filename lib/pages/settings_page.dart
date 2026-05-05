import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fcm_box/theme_settings.dart';
import 'package:fcm_box/l10n/app_localizations.dart';
import 'package:fcm_box/locale_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final Future<void> Function()? onSync;

  const SettingsPage({super.key, this.onSync});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _useMonet = false;
  int _selectedColorValue = Colors.blue.toARGB32();
  String _languageCode = 'en';
  String _themeMode = 'system';
  bool _usePureDark = false;
  String _requestStorageDir = '';

  final List<Color> _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _updateThemeSettings() {
    ThemeMode themeMode;
    switch (_themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }
    themeSettingsNotifier.value = ThemeSettings(
      _useMonet,
      _selectedColorValue,
      themeMode,
      _usePureDark,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final resolvedDir = await _resolveFixedStorageDir();
    setState(() {
      _useMonet = prefs.getBool('use_monet') ?? false;
      _selectedColorValue =
          prefs.getInt('theme_color') ?? Colors.deepPurple.toARGB32();
      _languageCode = prefs.getString('language_code') ?? 'en';
      _themeMode = prefs.getString('theme_mode') ?? 'system';
      _usePureDark = prefs.getBool('use_pure_dark') ?? false;
      _requestStorageDir = resolvedDir;
    });
  }

  Future<void> _saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    setState(() {
      HapticFeedback.heavyImpact();
      _languageCode = code;
    });
    localeSettingsNotifier.value = LocaleSettings(Locale(code));
  }

  Future<void> _saveUseMonet(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_monet', value);
    setState(() {
      _useMonet = value;
    });
    _updateThemeSettings();
  }

  Future<void> _saveThemeColor(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', value);
    setState(() {
      _selectedColorValue = value;
    });
    _updateThemeSettings();
  }

  Future<void> _saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode);
    setState(() {
      _themeMode = mode;
    });
    _updateThemeSettings();
  }

  Future<void> _saveUsePureDark(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_pure_dark', value);
    setState(() {
      _usePureDark = value;
    });
    _updateThemeSettings();
  }

  Future<String> _resolveFixedStorageDir() async {
    if (Platform.isAndroid) {
      return p.join('/storage/emulated/0/Download', 'FCMBox');
    }
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'Downloads', 'FCMBox');
  }

  Future<void> _openRequestStorageDir() async {
    final localizations = AppLocalizations.of(context);
    if (_requestStorageDir.isEmpty) {
      Fluttertoast.showToast(
        msg: localizations?.storage_directory_not_set ?? 'Storage directory not set',
      );
      return;
    }

    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: Uri.encodeFull('file://$_requestStorageDir'),
          type: 'resource/folder',
        );
        await intent.launch();
      } else {
        final uri = Uri.file(_requestStorageDir);
        if (!await launchUrl(uri)) {
          Fluttertoast.showToast(
            msg: localizations?.failed_open_directory ?? 'Failed to open directory',
          );
        }
      }
    } catch (_) {
      Fluttertoast.showToast(
        msg: localizations?.failed_open_directory ?? 'Failed to open directory',
      );
    }
  }

  Future<void> _copyRequestStorageDir() async {
    if (_requestStorageDir.isEmpty) return;
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: _requestStorageDir));
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _colors.length,
            itemBuilder: (context, index) {
              final color = _colors[index];
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _saveThemeColor(color.toARGB32());
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  backgroundColor: color,
                  child: _selectedColorValue == color.toARGB32()
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.settings ?? 'Settings'),
      ),
      body: ListView(
        children: [
          // Theme section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              localizations?.theme_section ?? 'Theme',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: Text(localizations?.dark_mode ?? 'Dark Mode'),
            subtitle: Text(
              _themeMode == 'system'
                  ? (localizations?.system_default ?? 'System Default')
                  : _themeMode == 'dark'
                  ? (localizations?.on ?? 'On')
                  : (localizations?.off ?? 'Off'),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: Text(localizations?.dark_mode ?? 'Dark Mode'),
                    children: [
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveThemeMode('system');
                        },
                        child: Text(localizations?.system_default ?? 'System Default'),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveThemeMode('dark');
                        },
                        child: Text(localizations?.on ?? 'On'),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                          _saveThemeMode('light');
                        },
                        child: Text(localizations?.off ?? 'Off'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SwitchListTile(
            title: Text(localizations?.pure_dark_mode ?? 'Pure Dark Mode'),
            subtitle: Text(
              localizations?.pure_dark_mode_subtitle ?? 'Use pure black background in dark mode',
            ),
            value: _usePureDark,
            onChanged: (bool value) {
              HapticFeedback.lightImpact();
              _saveUsePureDark(value);
            },
          ),
          SwitchListTile(
            title: Text(localizations?.use_monet ?? 'Use Android Monet'),
            subtitle: Text(
              localizations?.use_android_monet_subtitle ?? 'Use dynamic colors from your wallpaper',
            ),
            value: _useMonet,
            onChanged: (bool value) {
              HapticFeedback.lightImpact();
              _saveUseMonet(value);
            },
          ),
          ListTile(
            title: Text(localizations?.theme_colors ?? 'Theme Colors'),
            subtitle: _useMonet
                ? Text(
                    localizations?.theme_color_subtitle_disabled ?? 'Disabled when Monet is enabled',
                  )
                : null,
            enabled: !_useMonet,
            trailing: CircleAvatar(
              backgroundColor: _useMonet
                  ? Color(_selectedColorValue).withValues(alpha: 0.5)
                  : Color(_selectedColorValue),
              radius: 12,
            ),
            onTap: _useMonet
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _showColorPicker(context);
                  },
          ),

          // Language section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              localizations?.language_section ?? 'Language',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(localizations?.language ?? 'Language'),
            trailing: SegmentedButton(
              segments: [
                ButtonSegment(
                  value: 'en',
                  label: Text(localizations?.english ?? 'English'),
                ),
                ButtonSegment(
                  value: 'zh',
                  label: Text(localizations?.chinese ?? '简体中文'),
                ),
              ],
              selected: {_languageCode},
              onSelectionChanged: (Set<String> newSelection) {
                _saveLanguage(newSelection.first);
              },
            ),
          ),

          // Request API section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              localizations?.request_api_section ?? 'Request API',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(
              localizations?.request_storage_directory ?? 'Storage Directory',
            ),
            subtitle: Text(
              _requestStorageDir.isEmpty
                  ? (localizations?.request_storage_path_empty ?? 'Not set')
                  : _requestStorageDir,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              _openRequestStorageDir();
            },
            onLongPress: _copyRequestStorageDir,
          ),

          // Permissions section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              localizations?.permissions_section ?? 'Permissions',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(
              localizations?.notification_permission ?? 'Notification Permission',
            ),
            subtitle: Text(
              localizations?.notification_permission_subtitle ?? 'Allow app to post notifications',
            ),
            onTap: () async {
              final status = await Permission.notification.status;
              if (status.isDenied) {
                await Permission.notification.request();
              } else if (status.isPermanentlyDenied) {
                openAppSettings();
              } else {
                if (context.mounted) {
                  Fluttertoast.showToast(
                    msg: localizations?.permission_granted ?? 'Permission already granted',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}