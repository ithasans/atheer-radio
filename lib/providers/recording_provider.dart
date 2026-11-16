import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class RecordingState {
  final bool isRecording;
  final int elapsedSeconds;
  final String? stationName;
  final String? filePath;

  const RecordingState({
    this.isRecording = false,
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
    int? elapsedSeconds,
    String? stationName,
    String? filePath,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
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
  StreamSubscription<List<int>>? _subscription;
  http.Client? _client;
  IOSink? _sink;
  Timer? _timer;

  RecordingNotifier() : super(const RecordingState());

  String _sanitizePrefix(String? stationName) {
    if (stationName == null || stationName.trim().isEmpty) return 'Atheer_Live';
    final ascii = stationName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (ascii.length >= 2) {
      return ascii.length > 20 ? ascii.substring(0, 20) : ascii;
    }
    return 'Atheer_Live';
  }

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

    try {
      final Directory? musicDir = await getExternalStorageDirectory();
      if (musicDir == null) {
        return 'error';
      }
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final prefix = _sanitizePrefix(stationName);
      final filePath = '${musicDir.path}/${prefix}_$stamp.mp3';
      final file = File(filePath);

      _client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await _client!.send(request);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        _client?.close();
        _client = null;
        return 'error';
      }

      _sink = file.openWrite(mode: FileMode.writeOnly);

      state = RecordingState(
        isRecording: true,
        elapsedSeconds: 0,
        stationName: stationName,
        filePath: filePath,
      );

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !state.isRecording) return;
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      });

      _subscription = response.stream.listen(
        (chunk) {
          _sink?.add(chunk);
        },
        onError: (_) => stopRecording(),
        onDone: () => stopRecording(),
        cancelOnError: true,
      );

      return 'started';
    } catch (_) {
      await _cleanup();
      state = const RecordingState(isRecording: false);
      return 'error';
    }
  }

  Future<void> stopRecording() async {
    await _cleanup();
    if (mounted) {
      state = const RecordingState(
        isRecording: false,
        elapsedSeconds: 0,
      );
    }
  }

  Future<void> _cleanup() async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // Ignore file flush errors during teardown
    }
    _sink = null;
    _client?.close();
    _client = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _sink?.close();
    _client?.close();
    super.dispose();
  }
}
