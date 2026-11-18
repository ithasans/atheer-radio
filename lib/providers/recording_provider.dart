import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/services/stream_recorder_service.dart';

class RecordingState {
  final bool isRecording;
  final bool isStarting;
  final int elapsedSeconds;
  final String? stationName;
  final String? filePath;

  const RecordingState({
    this.isRecording = false,
    this.isStarting = false,
    this.elapsedSeconds = 0,
    this.stationName,
    this.filePath,
  });

  String get formattedElapsed {
    final mins = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  RecordingState copyWith({
    bool? isRecording,
    bool? isStarting,
    int? elapsedSeconds,
    String? stationName,
    String? filePath,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      isStarting: isStarting ?? this.isStarting,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      stationName: stationName ?? this.stationName,
      filePath: filePath ?? this.filePath,
    );
  }
}

final recordingProvider = StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  return RecordingNotifier();
});

class RecordingNotifier extends StateNotifier<RecordingState> {
  final StreamRecorderService _recorder = StreamRecorderService();
  Timer? _timer;

  RecordingNotifier() : super(const RecordingState());

  /// Toggles live stream recording. Returns:
  /// - `'started'` when recording began
  /// - `'stopped'` when active recording was stopped and saved
  /// - `'error'` if starting recording failed
  Future<String> toggleRecording({
    required String streamUrl,
    String? stationName,
  }) async {
    if (state.isRecording) {
      await stopRecording();
      return 'stopped';
    }

    if (state.isStarting) return 'starting';

    state = state.copyWith(isStarting: true);

    try {
      final filePath = await _recorder.startRecording(
        streamUrl: streamUrl,
        stationName: stationName,
      );

      if (filePath == null) {
        state = const RecordingState(isRecording: false, isStarting: false);
        return 'error';
      }

      state = RecordingState(
        isRecording: true,
        isStarting: false,
        elapsedSeconds: 0,
        stationName: stationName,
        filePath: filePath,
      );

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !state.isRecording) return;
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      });

      return 'started';
    } catch (_) {
      await stopRecording();
      state = const RecordingState(isRecording: false, isStarting: false);
      return 'error';
    }
  }

  Future<void> stopRecording() async {
    _timer?.cancel();
    _timer = null;
    await _recorder.stopRecording();
    if (mounted) {
      state = const RecordingState(
        isRecording: false,
        isStarting: false,
        elapsedSeconds: 0,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.stopRecording();
    super.dispose();
  }
}
