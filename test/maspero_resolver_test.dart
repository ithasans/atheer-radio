import 'package:flutter_test/flutter_test.dart';
import 'package:myradio1/services/maspero_stream_resolver.dart';

void main() {
  group('MasperoStreamResolver Tests', () {
    test('getMasperoStations returns the 9 official Maspero stations with correct attributes', () {
      final stations = MasperoStreamResolver.getMasperoStations();

      expect(stations.length, equals(9));

      final names = stations.map((s) => s.name).toList();
      expect(names, contains('إذاعة الشرق الأوسط'));
      expect(names, contains('إذاعة صوت العرب'));
      expect(names, contains('إذاعة البرنامج العام'));
      expect(names, contains('إذاعة الشباب والرياضة'));
      expect(names, contains('إذاعة الأغاني'));
      expect(names, contains('إذاعة راديو مصر 88.7'));
      expect(names, contains('إذاعة القاهرة الكبرى'));
      expect(names, contains('إذاعة البرنامج الثقافي ودراما'));
      expect(names, contains('إذاعة البرنامج الأوروبي'));

      for (final s in stations) {
        expect(s.country, equals('مصر'));
        expect(s.countryCode, equals('EG'));
        expect(s.codec, equals('AAC'));
        expect(s.bitrate, equals(64));
        expect(s.streamUrl.startsWith('maspero://'), isTrue);
        expect(s.favicon, isNotNull);
        expect(s.favicon!.startsWith('https://'), isTrue);
        expect(MasperoStreamResolver.isMasperoUrl(s.streamUrl), isTrue);
      }
    });

    test('isMasperoUrl correctly detects Maspero URLs and ignores others', () {
      expect(MasperoStreamResolver.isMasperoUrl('maspero://x8n6drt'), isTrue);
      expect(MasperoStreamResolver.isMasperoUrl('maspero://x8n6dqq/audio'), isTrue);
      expect(MasperoStreamResolver.isMasperoUrl('https://www.maspero.eg/stream/x8n6dt3'), isTrue);
      expect(MasperoStreamResolver.isMasperoUrl('https://geo.dailymotion.com/player/xi5eg.html?video=x8n6dzo'), isTrue);

      expect(MasperoStreamResolver.isMasperoUrl('https://stream.radiojar.com/8s5u5tpdtwzuv'), isFalse);
      expect(MasperoStreamResolver.isMasperoUrl('http://9090streaming.mobtada.com/9090FMEGYPT'), isFalse);
      expect(MasperoStreamResolver.isMasperoUrl(''), isFalse);
      expect(MasperoStreamResolver.isMasperoUrl(null), isFalse);
    });

    test('extractVideoId extracts clean video IDs', () {
      expect(MasperoStreamResolver.extractVideoId('maspero://x8n6drt'), equals('x8n6drt'));
      expect(MasperoStreamResolver.extractVideoId('maspero://x8n6dqq?token=123'), equals('x8n6dqq'));
      expect(MasperoStreamResolver.extractVideoId('https://www.dailymotion.com/video/x8n6dyz'), equals('x8n6dyz'));
      expect(MasperoStreamResolver.extractVideoId('https://example.com/audio.mp3'), isNull);
    });
  });
}
