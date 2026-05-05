import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // 提供 debugPrint
import 'config.dart'; // 使用全局配置

class TurnstileUtils {
  // 直接使用全局后端 URL，无需外部传入
  Future<bool> verify(String turnstileToken) async {
    try {
      final backendUrl = await AppConfig.getBackendUrl();
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verify_turnstile',
          'turnstile_token': turnstileToken,
        }),
      ).timeout(const Duration(seconds: 10)); // 超时保护

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Turnstile verification error: $e');
      return false;
    }
  }
}