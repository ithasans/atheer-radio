import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/utils/encoding_utils.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler implements AppAudioHandler {
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player;
  String? _lastUrl;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  MyAudioHandler() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
    );

    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Live Stream ICY Metadata Extraction (Title, Track, Artist)
    _player.icyMetadataStream.listen((icy) {
      final rawIcyTitle = icy?.info?.title;
      final rawStationName = icy?.headers?.name;
      final current = mediaItem.value;
      if (current == null) return;

      final icyTitle = EncodingUtils.decodeStreamMetadata(rawIcyTitle);
      final stationName = EncodingUtils.decodeStreamMetadata(rawStationName);

      if (icyTitle.isNotEmpty) {
        final existingExtras = Map<String, dynamic>.from(current.extras ?? const {});
        existingExtras['icyTitle'] = icyTitle;
        mediaItem.add(
          current.copyWith(
            artist: icyTitle,
            extras: existingExtras,
          ),
        );
      } else if (stationName.isNotEmpty && current.title.isEmpty) {
        mediaItem.add(current.copyWith(title: stationName));
      }
    });

    // Player state monitoring & Auto-Reconnect on transient drops
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _lastUrl != null &&
          _retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('Reconnecting to stream (attempt $_retryCount/$_maxRetries)...');
        playFromUrl(
          _lastUrl!,
          title: mediaItem.value?.title,
          artist: mediaItem.value?.extras?['country']?.toString() ?? mediaItem.value?.artist,
          artUri: mediaItem.value?.artUri?.toString(),
        );
      } else if (state.playing) {
        _retryCount = 0;
      }
    });
  }

  @override
  AndroidEqualizer? get equalizer => _equalizer;

  @override
  Future<void> playFromUrl(String url, {String? title, String? artist, String? artUri}) async {
    _lastUrl = url;
    _retryCount = 0;
    final uri = Uri.parse(url);
    final decodedArtist = EncodingUtils.decodeStreamMetadata(artist);
    final country = decodedArtist.isNotEmpty ? decodedArtist : 'بث حي';
    final decodedTitle = EncodingUtils.decodeStreamMetadata(title);
    final cleanTitle = decodedTitle.isNotEmpty ? decodedTitle : 'راديو مباشر';

    final item = MediaItem(
      id: uri.toString(),
      title: cleanTitle,
      artist: country,
      artUri: (artUri != null && artUri.isNotEmpty) ? Uri.tryParse(artUri) : null,
      extras: {
        'country': country,
        'icyTitle': '',
      },
    );
    mediaItem.add(item);

    try {
      await _player.setAudioSource(AudioSource.uri(uri), preload: false);
      await _player.play();
    } catch (e) {
      debugPrint('Error loading audio source: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _lastUrl = null;
    await _player.stop();
    await playbackState.firstWhere((state) => state.processingState == AudioProcessingState.idle);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
