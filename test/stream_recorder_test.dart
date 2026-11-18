import 'package:flutter_test/flutter_test.dart';
import 'package:myradio1/services/stream_recorder_service.dart';

void main() {
  group('StreamRecorderService Tests', () {
    test('sanitizePrefix produces clean file names', () {
      expect(StreamRecorderService.sanitizePrefix('الشرق الاوسط'), 'Atheer_Live');
      expect(StreamRecorderService.sanitizePrefix('Radio_Cairo_909'), 'Radio_Cairo_909');
      expect(StreamRecorderService.sanitizePrefix(null), 'Atheer_Live');
      expect(StreamRecorderService.sanitizePrefix('   '), 'Atheer_Live');
      expect(StreamRecorderService.sanitizePrefix('Asharq News 123'), 'Asharq_News_123');
    });

    test('Identifies HLS streams from URL patterns', () {
      const hlsUrl =
          'https://live.eu-north-1b.cf.dmcdn.net/sec2(...)/dm/3/x8n6drt/s/live-aac-128.m3u8#cell=lcf-eu-north-1b';
      final cleanUrl = hlsUrl.split('#').first.trim();
      final uri = Uri.parse(cleanUrl);
      final isHls = uri.path.toLowerCase().endsWith('.m3u8');
      expect(isHls, isTrue);
    });
  });
}
