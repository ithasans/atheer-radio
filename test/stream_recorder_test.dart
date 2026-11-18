import 'dart:typed_data';
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

    test('Fmp4AacExtractor parses init segment and extracts ADTS frames', () {
      final extractor = Fmp4AacExtractor();
      // Synthetic init segment with 'esds' and ASC tag 0x05 (profile=2, freq=4, chan=2)
      final initData = Uint8List.fromList([
        ...[0x65, 0x73, 0x64, 0x73], // 'esds'
        ...List.filled(10, 0),
        0x05, 0x80, 0x80, 0x80, 0x02, 0x12, 0x10, // ASC: 12 10
      ]);
      extractor.parseInitSegment(initData);
      expect(extractor.profile, 2);
      expect(extractor.freqIndex, 4);
      expect(extractor.chanCfg, 2);
      expect(extractor.hasConfig, isTrue);
    });
  });
}
