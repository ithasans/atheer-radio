import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myradio1/services/stream_recorder_service.dart';

void main() {
  group('StreamRecorderService Tests', () {
    test('sanitizePrefix preserves full Arabic and English station names without truncation', () {
      expect(StreamRecorderService.sanitizePrefix('الشرق الاوسط أثير العالم'), 'الشرق الاوسط أثير العالم');
      expect(StreamRecorderService.sanitizePrefix('Radio Cairo 909 FM'), 'Radio Cairo 909 FM');
      expect(StreamRecorderService.sanitizePrefix(null), 'Atheer_Live');
      expect(StreamRecorderService.sanitizePrefix('   '), 'Atheer_Live');
      expect(StreamRecorderService.sanitizePrefix('Asharq/News*123'), 'Asharq News 123');
    });

    test('Identifies HLS streams from URL patterns', () {
      const hlsUrl =
          'https://live.eu-north-1b.cf.dmcdn.net/sec2(...)/dm/3/x8n6drt/s/live-aac-128.m3u8#cell=lcf-eu-north-1b';
      final cleanUrl = hlsUrl.split('#').first.trim();
      final uri = Uri.parse(cleanUrl);
      final isHls = uri.path.toLowerCase().endsWith('.m3u8');
      expect(isHls, isTrue);
    });

    test('Fmp4AacExtractor parses init segment via esds and mp4a boxes', () {
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

      // Fallback via mp4a box (channelcount=2 at +20, samplerate 48000 at +28)
      final mp4aExtractor = Fmp4AacExtractor();
      final mp4aData = Uint8List.fromList([
        ...[0x6D, 0x70, 0x34, 0x61], // 'mp4a'
        ...List.filled(16, 0),
        0x00, 0x02, // channels = 2
        ...List.filled(6, 0),
        0xBB, 0x80, // 48000 Hz
        0x00, 0x00,
      ]);
      mp4aExtractor.parseInitSegment(mp4aData);
      expect(mp4aExtractor.chanCfg, 2);
      expect(mp4aExtractor.freqIndex, 3); // 48000 Hz is index 3
      expect(mp4aExtractor.hasConfig, isTrue);
    });

    test('Fmp4AacExtractor extracts bit-perfect ADTS frames from m4s chunks', () {
      final extractor = Fmp4AacExtractor();
      extractor.profile = 2; // AAC LC
      extractor.freqIndex = 4; // 44100 Hz
      extractor.chanCfg = 2; // Stereo

      // Build synthetic fMP4 chunk: moof + trun + mdat
      final samplePayload = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]); // 10 bytes
      final trunData = <int>[
        0x74, 0x72, 0x75, 0x6E, // 'trun'
        0x00, // version 0
        0x00, 0x02, 0x01, // flags: data_offset_present (0x01) + sample_size_present (0x200)
        0x00, 0x00, 0x00, 0x01, // sample_count = 1
        0x00, 0x00, 0x00, 0x30, // data_offset = 48 bytes from moofStart (32 moof + 8 pad + 8 mdat header)
        0x00, 0x00, 0x00, 0x0A, // sample_size = 10
      ];

      final moofData = <int>[
        0x00, 0x00, 0x00, 0x20, // moof size = 32
        0x6D, 0x6F, 0x6F, 0x66, // 'moof'
        ...trunData,
      ];

      // Pad up to offset 40 (moof size is 4 + 4 + 24 = 32 bytes, so 8 bytes padding before mdat payload)
      while (moofData.length < 40) {
        moofData.add(0);
      }

      final mdatData = <int>[
        0x00, 0x00, 0x00, 0x12, // mdat size = 18
        0x6D, 0x64, 0x61, 0x74, // 'mdat'
        ...samplePayload,
      ];

      final chunkData = Uint8List.fromList([...moofData, ...mdatData]);

      final adtsBytes = extractor.extractAdtsFromM4s(chunkData);
      expect(adtsBytes, isNotNull);
      // ADTS header is 7 bytes, payload is 10 bytes -> total 17 bytes
      expect(adtsBytes!.length, 17);
      // Check ADTS syncword (0xFF, 0xF1)
      expect(adtsBytes[0], 0xFF);
      expect(adtsBytes[1], 0xF1);
      // Check payload starts at index 7
      expect(adtsBytes.sublist(7), samplePayload);
    });
  });
}
