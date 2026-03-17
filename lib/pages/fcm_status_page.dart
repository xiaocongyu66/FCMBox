import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:fcm_box/localization.dart';

class FcmStatusPage extends StatefulWidget {
  const FcmStatusPage({super.key});

  @override
  State<FcmStatusPage> createState() => _FcmStatusPageState();
}

class _FcmStatusPageState extends State<FcmStatusPage> with WidgetsBindingObserver {
  bool _isGoogleServiceEnabled = false;
  bool _googleServiceChecked = false;
  bool _isVpnUsed = false;

  bool _isConnected = false;
  String _host = 'Loading...';
  String _port = 'Unknown';
  _FcmTokenState _tokenState = _FcmTokenState.loading;
  String _fcmToken = '';
  String _fcmTokenError = '';

  bool _diagnosticsLoading = true;
  bool _diagnosticsAvailable = false;
  String _diagnosticsSummary = '';
  String _diagnosticsRaw = '';
  bool _diagnosticsFetching = false;
  DateTime? _lastDiagnosticsFetch;
  DateTime? _lastGoogleServiceCheck;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _fetchStatus();
  }

  @override
  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _fetchStatus();
    } else if (state == AppLifecycleState.paused) {
      _stopTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchStatus();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchStatus() async {
    _checkGooglePlayServices();
    _fetchDiagnostics();

    // 1. Check VPN
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      bool hasVpn = false;
      for (var interface in interfaces) {
        if (interface.name.contains('tun') || 
            interface.name.contains('ppp') || 
            interface.name.contains('wg') || 
            interface.name.contains('tap')) {
          hasVpn = true;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _isVpnUsed = hasVpn;
        });
      }
    } catch (_) {}

    // 2. Fetch Token
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (mounted) {
        setState(() {
          if (token == null || token.isEmpty) {
            _tokenState = _FcmTokenState.failed;
            _fcmToken = '';
          } else {
            _tokenState = _FcmTokenState.success;
            _fcmToken = token;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tokenState = _FcmTokenState.error;
          _fcmTokenError = e.toString();
        });
      }
    }

    // Reset TCP status before parsing
    bool isConnected = false;
    String host = 'mtalk.google.com';
    String port = 'Unknown';
    String? foundIp;

    // 3. DNS Lookup (Base fallback)
    try {
      final results = await InternetAddress.lookup('mtalk.google.com');
      if (results.isNotEmpty && results[0].rawAddress.isNotEmpty) {
         host = 'mtalk.google.com/${results[0].address}';
      }
    } catch (_) {}
    
    if (Platform.isAndroid) {
      // Check IPv4 connections
      try {
        final file = File('/proc/net/tcp');
        if (file.existsSync()) {
          final lines = file.readAsLinesSync();
          for (var line in lines.skip(1)) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length > 3) {
              final remAddr = parts[2];
              final state = parts[3];
              if (state == '01') { // ESTABLISHED
                 final hostPort = remAddr.split(':');
                 if (hostPort.length == 2) {
                   final portHex = hostPort[1];
                   final portInt = int.parse(portHex, radix: 16);
                   if (portInt == 5228 || portInt == 5229 || portInt == 5230) {
                      final ipHex = hostPort[0];
                      final ipParts = <int>[];
                      for(int i = 0; i < ipHex.length; i += 2) {
                         ipParts.add(int.parse(ipHex.substring(i, i+2), radix: 16));
                      }
                      if (ipParts.length == 4) {
                        foundIp = '${ipParts[3]}.${ipParts[2]}.${ipParts[1]}.${ipParts[0]}';
                        port = portInt.toString();
                        isConnected = true;
                        break;
                      }
                   }
                 }
              }
            }
          }
        }
      } catch (_) {}

      // Check IPv6 connections if not found
      if (!isConnected) {
        try {
          final file = File('/proc/net/tcp6');
          if (file.existsSync()) {
            final lines = file.readAsLinesSync();
            for (var line in lines.skip(1)) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.length > 3) {
                final remAddr = parts[2];
                final state = parts[3];
                if (state == '01') { // ESTABLISHED
                   final hostPort = remAddr.split(':');
                   if (hostPort.length == 2) {
                     final portHex = hostPort[1];
                     final portInt = int.parse(portHex, radix: 16);
                     if (portInt == 5228 || portInt == 5229 || portInt == 5230) {
                        final ipHex = hostPort[0];
                        if (ipHex.length == 32) {
                          final ipParts = <String>[];
                          for(int i = 0; i < 32; i += 8) {
                             final group = ipHex.substring(i, i+8);
                             final part1 = group.substring(6,8) + group.substring(4,6);
                             final part2 = group.substring(2,4) + group.substring(0,2);
                             ipParts.add(part1);
                             ipParts.add(part2);
                          }
                          foundIp = ipParts.join(':');
                          port = portInt.toString();
                          isConnected = true;
                          break;
                        }
                     }
                   }
                }
              }
            }
          }
        } catch (_) {}
      }

      if (isConnected && foundIp != null) {
         try {
           final reverseInfo = await InternetAddress(foundIp).reverse();
           host = '${reverseInfo.host}/$foundIp';
         } catch (_) {
           host = 'mtalk.google.com/$foundIp';
         }
      }
    }

    if (mounted) {
      setState(() {
         _isConnected = isConnected;
         _host = host;
         _port = port;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    final tr = AppLocalizations.of(context);
    Fluttertoast.showToast(
      msg: tr?.translate('copied_to_clipboard') ?? '$label copied to clipboard',
    );
  }

  Future<void> _checkGooglePlayServices() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _isGoogleServiceEnabled = false;
          _googleServiceChecked = true;
        });
      }
      return;
    }

    final now = DateTime.now();
    if (_lastGoogleServiceCheck != null &&
        now.difference(_lastGoogleServiceCheck!) < const Duration(seconds: 15)) {
      return;
    }
    _lastGoogleServiceCheck = now;

    try {
      final result = await Process.run(
        'pm',
        ['list', 'packages', 'com.google.android.gms'],
      );
      if (mounted) {
        setState(() {
          _isGoogleServiceEnabled =
              result.exitCode == 0 && result.stdout.toString().contains('com.google.android.gms');
          _googleServiceChecked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isGoogleServiceEnabled = false;
          _googleServiceChecked = true;
        });
      }
    }
  }

  Future<void> _fetchDiagnostics() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        setState(() {
          _diagnosticsLoading = false;
          _diagnosticsAvailable = false;
          _diagnosticsSummary = '';
          _diagnosticsRaw = '';
        });
      }
      return;
    }

    if (_diagnosticsFetching) return;

    final now = DateTime.now();
    if (_lastDiagnosticsFetch != null &&
        now.difference(_lastDiagnosticsFetch!) < const Duration(seconds: 15)) {
      return;
    }
    _lastDiagnosticsFetch = now;
    _diagnosticsFetching = true;

    try {
      final result = await Process.run('dumpsys', ['gcm']);
      final output = result.exitCode == 0
          ? result.stdout.toString()
          : result.stderr.toString();
      final summary = _summarizeDiagnostics(output);
      if (mounted) {
        setState(() {
          _diagnosticsLoading = false;
          _diagnosticsAvailable = output.trim().isNotEmpty;
          _diagnosticsSummary = summary;
          _diagnosticsRaw = output.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _diagnosticsLoading = false;
          _diagnosticsAvailable = false;
          _diagnosticsSummary = '';
          _diagnosticsRaw = e.toString();
        });
      }
    } finally {
      _diagnosticsFetching = false;
    }
  }

  String _summarizeDiagnostics(String output) {
    final lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';

    final picked = <String>[];
    for (final line in lines) {
      if (picked.length >= 3) break;
      if (line.contains(':') && line.length <= 80) {
        picked.add(line);
      }
    }
    if (picked.isNotEmpty) {
      return picked.join(' | ');
    }
    return lines.first;
  }

  void _showDiagnosticsDialog() {
    final tr = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr?.translate('fcm_diagnostics') ?? 'FCM Diagnostics'),
        content: SizedBox(
          width: double.maxFinite,
          child: SelectableText(
            _diagnosticsRaw.isNotEmpty
                ? _diagnosticsRaw
                : (tr?.translate('fcm_diagnostics_unavailable') ??
                    'Diagnostics unavailable'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _copyToClipboard(
                _diagnosticsRaw,
                tr?.translate('fcm_diagnostics') ?? 'FCM Diagnostics',
              );
            },
            child: Text(tr?.translate('copy') ?? 'Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr?.translate('close') ?? 'Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final noneText = tr?.translate('fcm_none') ?? 'None';
    final loadingText = tr?.translate('fcm_loading') ?? 'Loading...';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(tr?.translate('fcm_status_title') ?? 'FCM Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: tr?.translate('fcm_open_diagnostics') ?? 'Open System FCM Diagnostics',
            onPressed: () {
              try {
                if (Platform.isAndroid) {
                  const AndroidIntent intent = AndroidIntent(
                    action: 'android.intent.action.MAIN',
                    package: 'com.google.android.gms',
                    componentName: 'com.google.android.gms.gcm.GcmDiagnostics',
                  );
                  intent.launch().catchError((e) {
                     Fluttertoast.showToast(
                       msg: tr?.translate('fcm_open_diagnostics_failed') ??
                           'Failed to open system diagnostics',
                     );
                  });
                }
              } catch (_) {}
            },
          )
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              tr?.translate('fcm_environment') ?? 'Environment',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_google_service') ?? 'Google Service'),
            subtitle: Text(!_googleServiceChecked
                ? loadingText
                : (_isGoogleServiceEnabled
                    ? (tr?.translate('fcm_enabled') ?? 'Enabled')
                    : (tr?.translate('fcm_disabled') ?? 'Disabled'))),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_vpn') ?? 'VPN'),
            subtitle: Text(_isVpnUsed ? 'True' : 'False'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              tr?.translate('fcm_system_diagnostics') ?? 'System Diagnostics',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_diagnostics') ?? 'FCM Diagnostics'),
            subtitle: Text(_diagnosticsLoading
                ? loadingText
                : (_diagnosticsAvailable
                    ? (_diagnosticsSummary.isNotEmpty
                        ? _diagnosticsSummary
                        : (tr?.translate('fcm_diagnostics_tap') ??
                            'Tap to view'))
                    : (tr?.translate('fcm_diagnostics_unavailable') ??
                        'Diagnostics unavailable'))),
            onTap: _diagnosticsAvailable ? _showDiagnosticsDialog : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              tr?.translate('fcm_status_title') ?? 'FCM Status',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_server') ?? 'Server'),
            subtitle: Text(_isConnected 
              ? (tr?.translate('fcm_connected') ?? 'Connected') 
              : (tr?.translate('fcm_disconnected') ?? 'Disconnected')),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_host') ?? 'Host'),
            subtitle: Text(_isConnected ? _host : noneText),
            onLongPress: _isConnected ? () => _copyToClipboard(_host, tr?.translate('fcm_host') ?? 'Host') : null,
          ),
          ListTile(
            title: Text(tr?.translate('fcm_port') ?? 'Port'),
            subtitle: Text(_isConnected ? _port : noneText),
          ),
          ListTile(
            title: Text(tr?.translate('fcm_token') ?? 'FCM Token'),
            subtitle: Text(
              _buildTokenStatusText(tr),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onLongPress: () => _copyToClipboard(
              _buildTokenStatusText(tr),
              tr?.translate('fcm_token') ?? 'FCM Token',
            ),
          ),
        ],
      ),
    );
  }

  String _buildTokenStatusText(AppLocalizations? tr) {
    switch (_tokenState) {
      case _FcmTokenState.loading:
        return tr?.translate('fcm_loading') ?? 'Loading...';
      case _FcmTokenState.success:
        return _fcmToken;
      case _FcmTokenState.failed:
        return tr?.translate('fcm_token_failed') ?? 'Failed to get token';
      case _FcmTokenState.error:
        final prefix = tr?.translate('fcm_error_prefix') ?? 'Error';
        return '$prefix: $_fcmTokenError';
    }
  }
}

enum _FcmTokenState {
  loading,
  success,
  failed,
  error,
}
