import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/services/share_service.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/widgets/audio_visualizer.dart';

class RecordingsScreen extends ConsumerStatefulWidget {
  const RecordingsScreen({super.key});

  @override
  ConsumerState<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends ConsumerState<RecordingsScreen> {
  final AudioPlayer _player = AudioPlayer();
  List<FileSystemEntity> _recordings = [];
  bool _isLoading = true;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadRecordings();

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing && state.processingState != ProcessingState.completed;
          if (state.processingState == ProcessingState.completed) {
            _currentPosition = Duration.zero;
          }
        });
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
      }
    });

    _player.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() => _totalDuration = dur);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);
    try {
      final Directory? musicDir = await getExternalStorageDirectory();
      if (musicDir != null && await musicDir.exists()) {
        const supportedExtensions = ['.mp3', '.m4a', '.aac', '.ogg', '.wav', '.flac', '.ts'];
        final files = musicDir.listSync().where((f) {
          final lower = f.path.toLowerCase();
          return supportedExtensions.any((ext) => lower.endsWith(ext));
        }).toList();
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        if (mounted) {
          setState(() {
            _recordings = files;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _playRecording(String path) async {
    if (_currentlyPlayingPath == path) {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } else {
      try {
        await _player.stop();
        setState(() {
          _currentlyPlayingPath = path;
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
        });
        await _player.setFilePath(path);
        await _player.play();
      } catch (e) {
        debugPrint("Error playing recorded file: $e");
      }
    }
  }

  Future<void> _deleteRecording(File file, String lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.get('delete_recording', lang)),
        content: Text(AppStrings.get('delete_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.get('cancel', lang)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRecord),
            child: Text(AppStrings.get('delete', lang), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_currentlyPlayingPath == file.path) {
        await _player.stop();
        _currentlyPlayingPath = null;
      }
      if (await file.exists()) {
        await file.delete();
      }
      _loadRecordings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('recording_deleted', lang))),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getStationTitle(String fileName) {
    String baseName = fileName;
    final dotIdx = fileName.lastIndexOf('.');
    if (dotIdx != -1) {
      baseName = fileName.substring(0, dotIdx);
    }
    final stampRegex = RegExp(r'_\d{8}_\d{6}$');
    if (stampRegex.hasMatch(baseName)) {
      final title = baseName.replaceFirst(stampRegex, '').trim();
      if (title.isNotEmpty) return title;
    }
    return baseName.trim();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final isRtl = lang == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.get('recordings_library', lang)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadRecordings,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _recordings.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mic_off_rounded, size: 64, color: AppTheme.textMuted),
                                const SizedBox(height: 16),
                                Text(
                                  AppStrings.get('no_recordings', lang),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _recordings.length,
                          itemBuilder: (context, index) {
                            final file = File(_recordings[index].path);
                            final stat = file.statSync();
                            final isCurrent = _currentlyPlayingPath == file.path;
                            final isCurrentlyPlaying = isCurrent && _isPlaying;
                            final fileName = file.path.split(Platform.pathSeparator).last;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppTheme.surfaceElevated : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCurrent ? AppTheme.primary.withValues(alpha: 0.6) : AppTheme.border,
                                  width: isCurrent ? 1.5 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _playRecording(file.path),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCurrent ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surfaceElevated,
                                        ),
                                        child: IconButton(
                                          icon: Icon(
                                            isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                                          ),
                                          onPressed: () => _playRecording(file.path),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _getStationTitle(fileName),
                                              maxLines: 2,
                                              overflow: TextOverflow.visible,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  _formatDate(stat.modified),
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.surface,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    _formatFileSize(stat.size),
                                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 0.8),
                                                  ),
                                                  child: Text(
                                                    fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'AUDIO',
                                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrentlyPlaying)
                                            const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4),
                                              child: AudioVisualizer(
                                                isPlaying: true,
                                                maxHeight: 14,
                                                width: 2.0,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                            tooltip: AppStrings.get('share_recording', lang),
                                            icon: const Icon(Icons.share_rounded, color: AppTheme.primary, size: 20),
                                            onPressed: () => ShareService.shareFile(file.path, title: fileName),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRecord, size: 21),
                                            onPressed: () => _deleteRecording(file, lang),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Interactive Bottom Playback Controller with Dynamic Slider
            if (_currentlyPlayingPath != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.border),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with file name and close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _currentlyPlayingPath!.split(Platform.pathSeparator).last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                            onPressed: () {
                              _player.stop();
                              setState(() => _currentlyPlayingPath = null);
                            },
                          ),
                        ],
                      ),

                      // Interactive Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: AppTheme.surface,
                          thumbColor: Colors.white,
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          min: 0.0,
                          max: _totalDuration.inMilliseconds.toDouble() > 0
                              ? _totalDuration.inMilliseconds.toDouble()
                              : 1.0,
                          value: _currentPosition.inMilliseconds
                              .toDouble()
                              .clamp(0.0, _totalDuration.inMilliseconds.toDouble() > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0),
                          onChanged: (val) {
                            _player.seek(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),

                      // Timestamps: Current / Total
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Transport buttons: -10s, Play/Pause, +10s
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, size: 26, color: AppTheme.textSecondary),
                            onPressed: () {
                              final newPos = _currentPosition - const Duration(seconds: 10);
                              _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                            },
                          ),
                          const SizedBox(width: 16),
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                            ),
                            child: IconButton(
                              iconSize: 32,
                              icon: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_isPlaying) {
                                  _player.pause();
                                } else {
                                  _player.play();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, size: 26, color: AppTheme.textSecondary),
                            onPressed: () {
                              final newPos = _currentPosition + const Duration(seconds: 10);
                              _player.seek(newPos > _totalDuration ? _totalDuration : newPos);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
