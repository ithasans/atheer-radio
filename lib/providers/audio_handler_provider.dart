import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/services/my_audio_handler.dart';

final currentStationProvider = StateProvider<Station?>((ref) => null);

/// A FutureProvider that initializes the AudioHandler with full background support.
final audioHandlerProvider = FutureProvider<AppAudioHandler>((ref) async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.hassanobeid.atheer_radio.audio',
      androidNotificationChannelName: 'Atheer Radio Playback',
      androidNotificationChannelDescription: 'Live radio streaming background playback controls',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: false,
      androidNotificationClickStartsActivity: true,
      notificationColor: Color(0xFF0284C7),
    ),
  );
});
