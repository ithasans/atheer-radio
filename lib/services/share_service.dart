import 'package:flutter/services.dart';

class ShareService {
  ShareService._();

  static const MethodChannel _channel = MethodChannel('com.hassanobeid.atheer_radio/share');

  static Future<bool> shareText(String text, {String? subject}) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject ?? '',
      });
      return result ?? true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareFile(String path, {String? title}) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'title': title ?? '',
      });
      return result ?? true;
    } catch (_) {
      return false;
    }
  }
}
