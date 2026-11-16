import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:myradio1/main.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/providers/audio_handler_provider.dart';
import 'package:myradio1/providers/favorites_provider.dart';
import 'package:myradio1/providers/recent_stations_provider.dart';
import 'package:myradio1/providers/sleep_timer_provider.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.mocks.dart';

@GenerateMocks([AppAudioHandler])
void main() {
  late MockAppAudioHandler mockAudioHandler;
  late BehaviorSubject<PlaybackState> playbackStateSubject;
  late BehaviorSubject<MediaItem?> mediaItemSubject;

  setUp(() {
    mockAudioHandler = MockAppAudioHandler();

    playbackStateSubject = BehaviorSubject<PlaybackState>.seeded(
      PlaybackState(
        controls: [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    mediaItemSubject = BehaviorSubject<MediaItem?>.seeded(
      const MediaItem(id: 'fake', title: 'Fake Radio'),
    );

    SharedPreferences.setMockInitialValues({});
    when(mockAudioHandler.playbackState).thenAnswer((_) => playbackStateSubject.stream);
    when(mockAudioHandler.mediaItem).thenAnswer((_) => mediaItemSubject.stream);
    when(mockAudioHandler.equalizer).thenReturn(null);
    when(mockAudioHandler.play()).thenAnswer((_) async {});
    when(mockAudioHandler.pause()).thenAnswer((_) async {});
    when(mockAudioHandler.setVolume(any)).thenAnswer((_) async {});
    when(mockAudioHandler.playFromUrl(
      any,
      title: anyNamed('title'),
      artist: anyNamed('artist'),
      artUri: anyNamed('artUri'),
    )).thenAnswer((_) async {});
  });

  tearDown(() {
    playbackStateSubject.close();
    mediaItemSubject.close();
  });

  testWidgets('RadioScreen renders main UI and tabs correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWith((ref) => Future.value(mockAudioHandler))
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('أثير العالم'), findsOneWidget);
    expect(find.byIcon(Icons.radio_rounded), findsOneWidget);
    expect(find.text('استكشاف'), findsOneWidget);
    expect(find.text('الأكثر شهرة'), findsOneWidget);
  });

  testWidgets('Drawer opens and contains all required items and developer info', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWith((ref) => Future.value(mockAudioHandler))
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Open drawer
    final scaffoldFinder = find.byType(Scaffold);
    final scaffoldState = tester.state<ScaffoldState>(scaffoldFinder);
    scaffoldState.openDrawer();
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify Home item
    expect(find.text('الرئيسية'), findsOneWidget);

    // Verify Theme item
    expect(find.text('المظهر الداكن'), findsOneWidget);

    // Verify Language item
    expect(find.text('لغة التطبيق'), findsOneWidget);

    // Verify Recordings Library item
    expect(find.text('مكتبة التسجيلات'), findsOneWidget);

    // Verify Sleep Timer, Add Custom Station, Drive Mode
    expect(find.text('مؤقت النوم'), findsOneWidget);
    expect(find.text('إضافة إذاعة مخصصة'), findsOneWidget);
    expect(find.text('وضع القيادة'), findsOneWidget);

    // Verify About Developer Card with name and email
    expect(find.text('حسن عبيد'), findsOneWidget);
    expect(find.text('ithasan4@gmail.com'), findsOneWidget);

    // Verify Copy and Share buttons exist
    expect(find.text('نسخ'), findsOneWidget);
    expect(find.text('مشاركة'), findsOneWidget);

    // Verify Exit button exists
    final exitFinder = find.text('الخروج من التطبيق');
    await tester.ensureVisible(exitFinder);
    expect(exitFinder, findsOneWidget);

    // Tap Exit button to verify confirmation dialog appears
    await tester.tap(exitFinder);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('تأكيد الخروج'), findsOneWidget);
    expect(find.text('هل أنت متأكد من رغبتك في إغلاق التطبيق؟'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('خروج'), findsOneWidget);
  });

  test('SleepTimerNotifier starts countdown and cancels properly', () {
    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWith((ref) => Future.value(mockAudioHandler))
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(sleepTimerProvider.notifier);
    expect(container.read(sleepTimerProvider).isActive, false);

    notifier.startTimer(15);
    expect(container.read(sleepTimerProvider).isActive, true);
    expect(container.read(sleepTimerProvider).remainingSeconds, 15 * 60);
    expect(container.read(sleepTimerProvider).formattedRemaining, '15:00');

    notifier.cancelTimer();
    expect(container.read(sleepTimerProvider).isActive, false);
    expect(container.read(sleepTimerProvider).remainingSeconds, 0);
  });

  test('FavoritesNotifier exports and imports backup JSON without duplicates', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(favoritesProvider.notifier);
    final st1 = Station(id: '1', name: 'Quran Live', streamUrl: 'https://example.com/1.mp3', country: 'Saudi Arabia');
    await notifier.toggleFavorite(st1);

    final backup = notifier.exportFavoritesJson();
    expect(backup.contains('Quran Live'), true);

    // Re-importing same backup adds 0 duplicates
    expect(await notifier.importFavoritesJson(backup), 0);

    // Importing invalid JSON returns -1
    expect(await notifier.importFavoritesJson('not json'), -1);

    // Importing new station adds 1
    const extraBackup = '[{"id":"2","name":"Cairo FM","url_resolved":"https://example.com/2.mp3","country":"Egypt"}]';
    expect(await notifier.importFavoritesJson(extraBackup), 1);
    expect(container.read(favoritesProvider).length, 2);
  });

  test('RecentStationsNotifier maintains unique recency order and cap', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recentStationsProvider.notifier);
    for (int i = 1; i <= 18; i++) {
      await notifier.addStation(
        Station(id: 's$i', name: 'Station $i', streamUrl: 'https://example.com/$i.mp3'),
      );
    }

    final list = container.read(recentStationsProvider);
    expect(list.length, 15);
    expect(list.first.id, 's18');

    // Re-playing s10 moves it to top without duplicate
    await notifier.addStation(
      Station(id: 's10', name: 'Station 10', streamUrl: 'https://example.com/10.mp3'),
    );
    final updated = container.read(recentStationsProvider);
    expect(updated.length, 15);
    expect(updated.first.id, 's10');

    await notifier.clearAll();
    expect(container.read(recentStationsProvider), isEmpty);
  });
}
