import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';          // 提供 Uint8List
import 'package:flutter/foundation.dart'; // 提供 debugPrint
import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoUtils {
  static const int _keyLength = 32; // AES-256
  static const int _ivLength = 16; // AES IV length

  /// 从 Authorization 密钥派生加密密钥
  static encrypt.Key deriveKey(String authKey) {
    final bytes = utf8.encode(authKey);
    final padded = bytes.length >= _keyLength
        ? bytes.sublist(0, _keyLength)
        : List<int>.from(bytes)..addAll(List.filled(_keyLength - bytes.length, 0));
    return encrypt.Key(Uint8List.fromList(padded));
  }

  /// 生成随机 IV
  static encrypt.IV generateIV() {
    final random = Random.secure();
    final ivBytes = List<int>.generate(
      _ivLength,
      (_) => random.nextInt(256),
    );
    return encrypt.IV(Uint8List.fromList(ivBytes));
  }

  /// 加密消息载荷 (data, overview, service)
  static String encryptMessage({
    required String data,
    required String overview,
    required String service,
    required String image,
    required String authKey,
  }) {
    final key = deriveKey(authKey);
    final iv = generateIV();

    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

    final payload = jsonEncode({
      'data': data,
      'overview': overview,
      'service': service,
      'image': image,
    });

    final encrypted = encrypter.encrypt(payload, iv: iv);

    return jsonEncode({
      'iv': base64Encode(iv.bytes),
      'encrypted': encrypted.base64,
    });
  }

  /// 解密消息载荷
  static Map<String, dynamic>? decryptMessage(
    String encryptedPayload,
    String authKey,
  ) {
    try {
      final key = deriveKey(authKey);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final payload = jsonDecode(encryptedPayload);
      final iv = encrypt.IV(base64Decode(payload['iv']));
      final decrypted = encrypter.decrypt64(payload['encrypted'], iv: iv);
      return jsonDecode(decrypted);
    } catch (e) {
      debugPrint('Decryption failed: $e');
      return null;
    }
  }
}