import 'package:flutter/material.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/theme/app_theme.dart';

class StationAvatar extends StatelessWidget {
  final Station station;
  final double size;
  final bool isCurrent;
  final bool isPlaying;

  const StationAvatar({
    super.key,
    required this.station,
    this.size = 50.0,
    this.isCurrent = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValidFavicon = station.favicon != null &&
        station.favicon!.startsWith('http') &&
        !station.favicon!.endsWith('.ico'); // .ico sometimes fails in Image.network

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCurrent ? AppTheme.primaryGradient : null,
        boxShadow: isCurrent && isPlaying
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      padding: isCurrent ? const EdgeInsets.all(2.5) : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: Container(
          color: AppTheme.surfaceElevated,
          child: hasValidFavicon
              ? Image.network(
                  station.favicon!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildFallback(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: size * 0.4,
                        height: size * 0.4,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                )
              : _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final initial = station.name.trim().isNotEmpty
        ? station.name.trim().characters.first
        : 'ر';

    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppTheme.cardGradient,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: isCurrent ? AppTheme.primary : AppTheme.textPrimary,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
