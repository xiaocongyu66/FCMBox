import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // ---------- 后端 API ----------
  static const String cloudflareBackendHost = 'fcmbox.x9n2.qzz.io';
  static const String firebaseBackendHost = 'fcmbox.firebase.wepayto.win/api';
  
  // 预设的完整后端 URL
  static const String cloudflareDefaultUrl = 'https://fcmbox.x9n2.qzz.io';
  static const String firebaseDefaultUrl = 'https://fcmbox.firebase.wepayto.win/api';

  // ---------- GitHub 信息 ----------
  static const String githubOwner = 'xiaocongyu66';
  static const String githubRepo = 'FCMBox';
  
  // 文档和 Issue 链接
  static const String documentationUrl = 'https://docs.wepayto.win/application/fcmbox/';
  static const String repoUrl = 'https://github.com/$githubOwner/$githubRepo';
  static const String issuesUrl = 'https://github.com/$githubOwner/$githubRepo/issues';
  static const String codeSampleUrl = 'https://github.com/$githubOwner/$githubRepo/blob/main/backendsample/README.md';

  // ---------- Turnstile 人机验证 ----------
  static const String turnstileSiteKey = '0x4AAAAAADJkNSfgciYSMs2C';

  // ---------- 其他常量 ----------
  static const String appTitle = 'FCM Box';
  static const String defaultNotificationChannelId = 'high_importance_channel';
  static const String appVersion = '2.1.1';

  // ---------- 动态获取后端 URL ----------
  /// 从 SharedPreferences 读取配置并构建完整的后端 URL
  /// 如果用户已配置，返回用户自定义的 URL；否则返回默认 Cloudflare URL
  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('backend_url');
    final useHttps = prefs.getBool('backend_https') ?? true;
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
      final cleanUrl = savedUrl.replaceAll(RegExp(r'^https?://'), '');
      return (useHttps ? 'https://' : 'http://') + cleanUrl;
    }
    
    return cloudflareDefaultUrl; // 默认值
  }
}