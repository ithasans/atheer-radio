import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Abstract interface for the application's audio handler.
abstract class AppAudioHandler implements AudioHandler {
  /// Play a live stream URL with optional metadata.
  Future<void> playFromUrl(String url, {String? title, String? artist, String? artUri});

  /// Adjust playback volume (0.0 to 1.0).
  Future<void> setVolume(double volume);

  /// Optional Android equalizer effect attached to the audio pipeline.
  AndroidEqualizer? get equalizer;
}
