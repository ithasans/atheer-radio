import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/services/app_audio_handler.dart';
import 'package:myradio1/theme/app_theme.dart';

class EqualizerSheet extends ConsumerWidget {
  final AppAudioHandler audioHandler;

  const EqualizerSheet({
    super.key,
    required this.audioHandler,
  });

  String _formatHz(double centerHz) {
    if (centerHz >= 1000) {
      final khz = centerHz / 1000;
      return '${khz.toStringAsFixed(khz.truncateToDouble() == khz ? 0 : 1)} kHz';
    }
    return '${centerHz.round()} Hz';
  }

  Future<void> _applyPreset(
    AndroidEqualizer equalizer,
    AndroidEqualizerParameters params,
    List<double> ratios,
  ) async {
    await equalizer.setEnabled(true);
    final bands = params.bands;
    for (int i = 0; i < bands.length; i++) {
      final ratioIdx = ((i / bands.length) * ratios.length).floor().clamp(0, ratios.length - 1);
      final targetGain = (ratios[ratioIdx] * params.maxDecibels)
          .clamp(params.minDecibels, params.maxDecibels);
      await bands[i].setGain(targetGain);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final isRtl = lang == 'ar';
    final equalizer = audioHandler.equalizer;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.equalizer_rounded, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.get('equalizer', lang),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (equalizer != null)
                      StreamBuilder<bool>(
                        stream: equalizer.enabledStream,
                        initialData: equalizer.enabled,
                        builder: (context, snapshot) {
                          final enabled = snapshot.data ?? false;
                          return Switch.adaptive(
                            value: enabled,
                            activeTrackColor: AppTheme.primary,
                            onChanged: (val) => equalizer.setEnabled(val),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (equalizer == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      AppStrings.get('eq_play_first', lang),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  )
                else
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, stateSnap) {
                      final processing = stateSnap.data?.processingState ?? AudioProcessingState.idle;
                      return FutureBuilder<AndroidEqualizerParameters>(
                        future: equalizer.parameters,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            if (processing == AudioProcessingState.idle) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 28),
                                child: Column(
                                  children: [
                                    const Icon(Icons.music_note_rounded, size: 42, color: AppTheme.textMuted),
                                    const SizedBox(height: 12),
                                    Text(
                                      AppStrings.get('eq_play_first', lang),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: CircularProgressIndicator(color: AppTheme.primary),
                              ),
                            );
                          }

                          final params = snapshot.data!;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Quick Presets
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _presetChip(
                                      context,
                                      label: AppStrings.get('eq_flat', lang),
                                      onTap: () => _applyPreset(equalizer, params, [0.0, 0.0, 0.0, 0.0, 0.0]),
                                    ),
                                    const SizedBox(width: 8),
                                    _presetChip(
                                      context,
                                      label: AppStrings.get('eq_bass', lang),
                                      onTap: () => _applyPreset(equalizer, params, [0.7, 0.45, 0.0, 0.1, 0.2]),
                                    ),
                                    const SizedBox(width: 8),
                                    _presetChip(
                                      context,
                                      label: AppStrings.get('eq_vocal', lang),
                                      onTap: () => _applyPreset(equalizer, params, [-0.2, 0.1, 0.55, 0.5, 0.1]),
                                    ),
                                    const SizedBox(width: 8),
                                    _presetChip(
                                      context,
                                      label: AppStrings.get('eq_classic', lang),
                                      onTap: () => _applyPreset(equalizer, params, [0.4, 0.2, -0.1, 0.3, 0.5]),
                                    ),
                                    const SizedBox(width: 8),
                                    _presetChip(
                                      context,
                                      label: AppStrings.get('eq_pop', lang),
                                      onTap: () => _applyPreset(equalizer, params, [0.2, 0.45, 0.3, 0.1, 0.35]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Frequency Bands
                              ...params.bands.map((band) {
                                return StreamBuilder<double>(
                                  stream: band.gainStream,
                                  initialData: band.gain,
                                  builder: (context, gainSnap) {
                                    final gain = (gainSnap.data ?? band.gain)
                                        .clamp(params.minDecibels, params.maxDecibels);
                                    return Row(
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          child: Text(
                                            _formatHz(band.centerFrequency),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: AppTheme.primary,
                                              inactiveTrackColor: AppTheme.surfaceElevated,
                                              thumbColor: AppTheme.primary,
                                              trackHeight: 3.5,
                                            ),
                                            child: Slider(
                                              min: params.minDecibels,
                                              max: params.maxDecibels,
                                              value: gain,
                                              onChanged: (val) => band.setGain(val),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 52,
                                          child: Text(
                                            '${gain.toStringAsFixed(1)} dB',
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetChip(BuildContext context, {required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: AppTheme.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onPressed: onTap,
    );
  }
}
