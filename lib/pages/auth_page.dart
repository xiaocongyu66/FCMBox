import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../l10n/app_localizations.dart';
import '../utils/crypto_utils.dart';

class AuthPage extends StatefulWidget {
  final String backendUrl;
  final VoidCallback? onAuthSuccess;

  const AuthPage({
    super.key,
    required this.backendUrl,
    this.onAuthSuccess,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _authController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;
  String? _error;
  String? _turnstileToken;
  String? _registeredAuth;
  String? _deviceName;

  static const _turnstileSiteKey = 'YOUR_TURNSTILE_SITE_KEY';

  @override
  void initState() {
    super.initState();
    _loadExistingAuth();
    _getDeviceName();
  }

  Future<void> _loadExistingAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('backend_auth');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _authController.text = saved);
    }
  }

  Future<void> _getDeviceName() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _deviceName = info.model;
    } catch (_) {
      _deviceName = 'Unknown Device';
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_isRegistering && _turnstileToken == null) {
      setState(() => _error = '请先完成人机验证');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = _authController.text.trim();
      final body = <String, dynamic>{
        'action': _isRegistering ? 'register' : 'check_auth',
        'auth': auth,
      };
      if (_isRegistering && _turnstileToken != null) {
        body['turnstile_token'] = _turnstileToken;
        body['device'] = _deviceName ?? 'Unknown Device';
      }

      final response = await http.post(
        Uri.parse(widget.backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backend_auth', auth);
        setState(() => _registeredAuth = auth);
        widget.onAuthSuccess?.call();
        if (mounted) Navigator.pop(context, auth);
      } else {
        setState(
          () => _error = '${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isRegistering
              ? (AppLocalizations.of(context)?.register ?? '注册')
              : (AppLocalizations.of(context)?.login ?? '登录'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isRegistering ? '创建新账号' : '登录账号',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _authController,
                decoration: InputDecoration(
                  labelText: '授权密钥',
                  hintText: _isRegistering ? '输入任意密钥' : '输入已有密钥',
                ),
                validator:
                    (v) => (v == null || v.trim().length < 8)
                        ? '至少8个字符'
                        : null,
              ),
              if (_registeredAuth != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    '已注册密钥: $_registeredAuth\n请妥善保管！',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
              if (_isRegistering) ...[
                const SizedBox(height: 16),
                const Text(
                  '人机验证',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                CloudflareTurnstile(
                  siteKey: _turnstileSiteKey,
                  onTokenReceived: (token) {
                    setState(() => _turnstileToken = token);
                  },
                ),
              ],
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(_isRegistering ? '注册' : '登录'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                    _error = null;
                  });
                },
                child: Text(
                  _isRegistering ? '已有账号？点击登录' : '没有账号？点击注册',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}