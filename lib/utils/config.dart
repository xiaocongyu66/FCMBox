class AppConfig {
  // ---------- 后端 API ----------
  static const String cloudflareBackendHost = 'fcmbackend.wepayto.win';
  static const String firebaseBackendHost = 'fcmbox.firebase.wepayto.win/api';
  
  // 预设的完整后端 URL
  static const String cloudflareDefaultUrl = 'https://fcmbackend.wepayto.win';
  static const String firebaseDefaultUrl = 'https://fcmbox.firebase.wepayto.win/api';

  // ---------- GitHub 信息 ----------
  static const String githubOwner = '你的GitHub用户名';      // 改成你自己的
  static const String githubRepo = 'FCMBox';
  
  // 文档和 Issue 链接
  static const String documentationUrl = 'https://docs.wepayto.win/application/fcmbox/';
  static const String repoUrl = 'https://github.com/$githubOwner/$githubRepo';
  static const String issuesUrl = 'https://github.com/$githubOwner/$githubRepo/issues';
  static const String codeSampleUrl = 'https://github.com/$githubOwner/$githubRepo/blob/main/backendsample/README.md';

  // ---------- Turnstile 人机验证 ----------
  static const String turnstileSiteKey = 'YOUR_TURNSTILE_SITE_KEY';   // 替换成你的 Site Key

  // ---------- 其他常量 ----------
  static const String appTitle = 'FCM Box';
  static const String defaultNotificationChannelId = 'high_importance_channel';
  static const String appVersion = '2.1.0';   // 与 pubspec.yaml 中的 version 保持一致
}

