import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/providers/favorites_provider.dart';
import 'package:myradio1/theme/app_theme.dart';
import 'package:myradio1/widgets/audio_visualizer.dart';
import 'package:myradio1/widgets/station_avatar.dart';

class StationCard extends ConsumerWidget {
  final Station station;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const StationCard({
    super.key,
    required this.station,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.any((s) => s.streamUrl == station.streamUrl || (s.id.isNotEmpty && s.id == station.id));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.surfaceElevated : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.border,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                StationAvatar(
                  station: station,
                  size: 48,
                  isCurrent: isCurrent,
                  isPlaying: isPlaying,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        station.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRect(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (station.country != null && station.country!.isNotEmpty) ...[
                                Text(
                                  station.country!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                          if (station.codec != null && station.codec!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border, width: 0.5),
                              ),
                              child: Text(
                                station.codec!.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (station.bitrate != null && station.bitrate! > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border, width: 0.5),
                              ),
                              child: Text(
                                '${station.bitrate}k',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                  ),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AudioVisualizer(
                      isPlaying: isPlaying,
                      maxHeight: 18,
                      width: 2.5,
                      color: AppTheme.primary,
                    ),
                  ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 20),
                    tooltip: 'تعديل',
                    onPressed: onEdit,
                  ),
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.redAccent : AppTheme.textMuted,
                    size: 22,
                  ),
                  onPressed: () {
                    ref.read(favoritesProvider.notifier).toggleFavorite(station);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
