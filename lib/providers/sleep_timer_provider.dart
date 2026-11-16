import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/providers/audio_handler_provider.dart';
import 'package:myradio1/providers/recording_provider.dart';

class SleepTimerState {
  final bool isActive;
  final int remainingSeconds;
  final int totalMinutes;

  const SleepTimerState({
    this.isActive = false,
    this.remainingSeconds = 0,
    this.totalMinutes = 0,
  });

  String get formattedRemaining {
    if (!isActive || remainingSeconds <= 0) return '';
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  SleepTimerState copyWith({
    bool? isActive,
    int? remainingSeconds,
    int? totalMinutes,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalMinutes: totalMinutes ?? this.totalMinutes,
    );
  }
}

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  final Ref _ref;
  Timer? _timer;

  SleepTimerNotifier(this._ref) : super(const SleepTimerState());

  void startTimer(int minutes) {
    cancelTimer();
    final totalSeconds = minutes * 60;
    state = SleepTimerState(
      isActive: true,
      remainingSeconds: totalSeconds,
      totalMinutes: minutes,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        state = const SleepTimerState(isActive: false, remainingSeconds: 0, totalMinutes: 0);
        _triggerStop();
      } else {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    state = const SleepTimerState(isActive: false, remainingSeconds: 0, totalMinutes: 0);
  }

  void _triggerStop() {
    _ref.read(audioHandlerProvider).whenData((handler) {
      handler.stop();
    });
    if (_ref.read(recordingProvider).isRecording) {
      _ref.read(recordingProvider.notifier).stopRecording();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
