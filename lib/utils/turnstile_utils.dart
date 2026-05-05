import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // 提供 debugPrint
import '../utils/config.dart'; // 修正为相对路径，指向统一配置文件

class TurnstileUtils {
  /// 向后端发起 Turnstile 验证
  /// 使用全局配置的后端地址，不需要外部传参
  static Future<bool> verify(String turnstileToken) async {
    try {
      final backendUrl = await AppConfig.getBackendUrl();
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verify_turnstile',
          'turnstileToken': turnstileToken,   // ✅ 与后端 Worker 字段名一致
        }),
      ).timeout(const Duration(seconds: 10)); // 超时保护

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Turnstile verification error: $e');
      return false;
    }
  }
}