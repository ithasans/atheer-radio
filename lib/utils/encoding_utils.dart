import 'dart:convert';

/// Utility class for detecting and fixing character encoding issues in live radio streams
/// (e.g., Icecast / Shoutcast metadata encoded in Windows-1256 or raw UTF-8 bytes
/// misparsed as ISO-8859-1 / Latin-1 by ExoPlayer / AVPlayer).
class EncodingUtils {
  EncodingUtils._();

  /// CP-1256 (Windows Arabic) mapping table for bytes 0x80 to 0xFF to Unicode code points.
  static const Map<int, int> _cp1256ToUnicode = {
    0x80: 0x20AC, // €
    0x81: 0x067E, // پ
    0x82: 0x201A, // ‚
    0x83: 0x0192, // ƒ
    0x84: 0x201E, // „
    0x85: 0x2026, // …
    0x86: 0x2020, // †
    0x87: 0x2021, // ‡
    0x88: 0x02C6, // ˆ
    0x89: 0x2030, // ‰
    0x8A: 0x0679, // ٹ
    0x8B: 0x2039, // ‹
    0x8C: 0x0152, // Œ
    0x8D: 0x0686, // چ
    0x8E: 0x0698, // ژ
    0x8F: 0x0688, // ڈ
    0x90: 0x06AF, // گ
    0x91: 0x2018, // ‘
    0x92: 0x2019, // ’
    0x93: 0x201C, // “
    0x94: 0x201D, // ”
    0x95: 0x2022, // •
    0x96: 0x2013, // –
    0x97: 0x2014, // —
    0x98: 0x06A9, // ک
    0x99: 0x2122, // ™
    0x9A: 0x0691, // ڑ
    0x9B: 0x203A, // ›
    0x9C: 0x0153, // œ
    0x9D: 0x200C, // ‌
    0x9E: 0x200D, // ‍
    0x9F: 0x06BA, // ں
    0xA0: 0x00A0, // NBSP
    0xA1: 0x060C, // ،
    0xA2: 0x00A2, // ¢
    0xA3: 0x00A3, // £
    0xA4: 0x00A4, // ¤
    0xA5: 0x00A5, // ¥
    0xA6: 0x00A6, // ¦
    0xA7: 0x00A7, // §
    0xA8: 0x00A8, // ¨
    0xA9: 0x00A9, // ©
    0xAA: 0x06BE, // ھ
    0xAB: 0x00AB, // «
    0xAC: 0x00AC, // ¬
    0xAD: 0x00AD, // Soft hyphen
    0xAE: 0x00AE, // ®
    0xAF: 0x00AF, // ¯
    0xB0: 0x00B0, // °
    0xB1: 0x00B1, // ±
    0xB2: 0x00B2, // ²
    0xB3: 0x00B3, // ³
    0xB4: 0x00B4, // ´
    0xB5: 0x00B5, // µ
    0xB6: 0x00B6, // ¶
    0xB7: 0x00B7, // ·
    0xB8: 0x00B8, // ¸
    0xB9: 0x00B9, // ¹
    0xBA: 0x061B, // ؛
    0xBB: 0x00BB, // »
    0xBC: 0x00BC, // ¼
    0xBD: 0x00BD, // ½
    0xBE: 0x00BE, // ¾
    0xBF: 0x061F, // ؟
    0xC0: 0x06C1, // ہ
    0xC1: 0x0621, // ء
    0xC2: 0x0622, // آ
    0xC3: 0x0623, // أ
    0xC4: 0x0624, // ؤ
    0xC5: 0x0625, // إ
    0xC6: 0x0626, // ئ
    0xC7: 0x0627, // ا
    0xC8: 0x0628, // ب
    0xC9: 0x0629, // ة
    0xCA: 0x062A, // ت
    0xCB: 0x062B, // ث
    0xCC: 0x062C, // ج
    0xCD: 0x062D, // ح
    0xCE: 0x062E, // خ
    0xCF: 0x062F, // د
    0xD0: 0x0630, // ذ
    0xD1: 0x0631, // ر
    0xD2: 0x0632, // ز
    0xD3: 0x0633, // س
    0xD4: 0x0634, // ش
    0xD5: 0x0635, // ص
    0xD6: 0x0636, // ض
    0xD7: 0x00D7, // ×
    0xD8: 0x0637, // ط
    0xD9: 0x0638, // ظ
    0xDA: 0x0639, // ع
    0xDB: 0x063A, // غ
    0xDC: 0x0640, // ـ
    0xDD: 0x0641, // ف
    0xDE: 0x0642, // ق
    0xDF: 0x0643, // ك
    0xE0: 0x00E0, // à
    0xE1: 0x0644, // ل
    0xE2: 0x00E2, // â
    0xE3: 0x0645, // م
    0xE4: 0x0646, // ن
    0xE5: 0x0647, // ه
    0xE6: 0x0648, // و
    0xE7: 0x00E7, // ç
    0xE8: 0x00E8, // è
    0xE9: 0x00E9, // é
    0xEA: 0x00EA, // ê
    0xEB: 0x00EB, // ë
    0xEC: 0x0649, // ى
    0xED: 0x064A, // ي
    0xEE: 0x00EE, // î
    0xEF: 0x00EF, // ï
    0xF0: 0x064B, // ً
    0xF1: 0x064C, // ٌ
    0xF2: 0x064D, // ٍ
    0xF3: 0x064E, // َ
    0xF4: 0x00F4, // ô
    0xF5: 0x064F, // ُ
    0xF6: 0x0650, // ِ
    0xF7: 0x00F7, // ÷
    0xF8: 0x0651, // ّ
    0xF9: 0x00F9, // ù
    0xFA: 0x0652, // ْ
    0xFB: 0x00FB, // û
    0xFC: 0x00FC, // ü
    0xFD: 0x200E, // LRM
    0xFE: 0x200F, // RLM
    0xFF: 0x06D2, // ے
  };

  /// Requires at least 2 consecutive Arabic letters to confirm authentic Arabic text
  /// rather than accidental collision with European accented characters (umlauts/accents).
  static final RegExp _consecutiveArabicLetters = RegExp(r'[\u0621-\u064A\u0671-\u06D3]{2,}');

  /// Unescapes common HTML entities that often appear in ICY metadata
  static String unescapeHtml(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  /// Automatically detects and fixes metadata strings with mojibake / wrong encoding.
  static String decodeStreamMetadata(String? input) {
    if (input == null) return '';
    var text = unescapeHtml(input).trim();
    if (text.isEmpty) return '';

    // If text already contains valid Arabic and no Latin-1 high bytes, keep as is
    final hasHighAscii = text.codeUnits.any((c) => c >= 128 && c <= 255);
    if (!hasHighAscii) {
      return text;
    }

    // Attempt 1: Check if bytes form a valid UTF-8 sequence that was misinterpreted as Latin-1
    final rawBytes = text.codeUnits.map((c) => c & 0xFF).toList();
    try {
      final decodedUtf8 = utf8.decode(rawBytes, allowMalformed: false);
      if (_consecutiveArabicLetters.hasMatch(decodedUtf8)) {
        return decodedUtf8;
      }
    } catch (_) {
      // Not valid UTF-8, proceed to CP-1256 check
    }

    // Attempt 2: Check CP-1256 (Windows Arabic)
    final sb = StringBuffer();
    for (final b in rawBytes) {
      if (b < 128) {
        sb.writeCharCode(b);
      } else {
        final mapped = _cp1256ToUnicode[b];
        sb.writeCharCode(mapped ?? b);
      }
    }

    final candidate = sb.toString();
    // Only accept CP-1256 decoding if it produces authentic consecutive Arabic letters
    if (_consecutiveArabicLetters.hasMatch(candidate)) {
      return candidate;
    }

    // Fallback: If no Arabic detected and original has Latin characters (e.g. German/French), return as is
    return text;
  }
}
