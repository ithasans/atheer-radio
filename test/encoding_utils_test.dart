import 'package:flutter_test/flutter_test.dart';
import 'package:myradio1/utils/encoding_utils.dart';

void main() {
  group('EncodingUtils Tests', () {
    test('Decodes Windows-1256 mojibake into correct Arabic', () {
      // The exact string from the user's friend's screenshot:
      const mojibake = 'ÇáÔíÎ ÚÈÏÇáÑÍãä ÇáÓÚÏí æÇáÔíÎ';
      final decoded = EncodingUtils.decodeStreamMetadata(mojibake);
      expect(decoded, 'الشيخ عبدالرحمن السعدي والشيخ');
    });

    test('Preserves properly-encoded UTF-8 Arabic', () {
      const cleanArabic = 'فريق المسحة - إنت اللحن اللي بأغنيه +';
      final result = EncodingUtils.decodeStreamMetadata(cleanArabic);
      expect(result, cleanArabic);
    });

    test('Preserves European/German characters with umlauts', () {
      const germanTitle = 'Radio München & Köln';
      final result = EncodingUtils.decodeStreamMetadata(germanTitle);
      expect(result, germanTitle);
    });

    test('Unescapes HTML entities in metadata', () {
      const htmlTitle = 'Tafsir &amp; Quran &#039;Al-Baqarah&#039;';
      final result = EncodingUtils.decodeStreamMetadata(htmlTitle);
      expect(result, "Tafsir & Quran 'Al-Baqarah'");
    });

    test('Handles empty and null strings safely', () {
      expect(EncodingUtils.decodeStreamMetadata(null), '');
      expect(EncodingUtils.decodeStreamMetadata(''), '');
      expect(EncodingUtils.decodeStreamMetadata('   '), '');
    });
  });
}
