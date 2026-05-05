import 'dart:convert';
import 'package:http/http.dart' as http;

class TurnstileUtils {
  final String backendUrl;

  TurnstileUtils(this.backendUrl);

  /// 向后端提交 Turnstile Token 进行验证
  Future<bool> verify(
    String turnstileToken, {
    String? siteKey,
    String? secretKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'verify_turnstile',
          'turnstile_token': turnstileToken,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Turnstile verification error: $e');
      return false;
    }
  }
}