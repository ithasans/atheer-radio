import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/providers/favorites_provider.dart';
import 'package:myradio1/providers/localization_provider.dart';
import 'package:myradio1/theme/app_theme.dart';

class AddStationScreen extends ConsumerStatefulWidget {
  final Station? stationToEdit;
  const AddStationScreen({super.key, this.stationToEdit});

  @override
  ConsumerState<AddStationScreen> createState() => _AddStationScreenState();
}

class _AddStationScreenState extends ConsumerState<AddStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _urlController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  bool _isTesting = false;
  String? _testMessage;
  Color? _testColor;
  IconData? _testIcon;
  bool _canPreview = false;
  bool _isPlayingPreview = false;
  AudioPlayer? _previewPlayer;

  final Map<String, List<double>> _capitals = {
    'uae': [24.4539, 54.3773],
    'إمارات': [24.4539, 54.3773],
    'الإمارات': [24.4539, 54.3773],
    'tunisia': [36.8065, 10.1815],
    'تونس': [36.8065, 10.1815],
    'egypt': [30.0444, 31.2357],
    'مصر': [30.0444, 31.2357],
    'saudi': [24.7136, 46.6753],
    'السعودية': [24.7136, 46.6753],
    'iraq': [33.3152, 44.3661],
    'العراق': [33.3152, 44.3661],
  };

  @override
  void initState() {
    super.initState();
    if (widget.stationToEdit != null) {
      final s = widget.stationToEdit!;
      _nameController.text = s.name;
      _countryController.text = s.country ?? '';
      _urlController.text = s.streamUrl;
      _latController.text = s.lat != null ? s.lat.toString() : '';
      _lonController.text = s.lon != null ? s.lon.toString() : '';
    }
  }

  @override
  void dispose() {
    _previewPlayer?.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _urlController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _testStream(String lang) async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('field_required', lang))),
      );
      return;
    }
    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('invalid_url', lang))),
      );
      return;
    }

    // Stop preview if running
    if (_previewPlayer != null && _isPlayingPreview) {
      await _previewPlayer!.stop();
      if (mounted) setState(() => _isPlayingPreview = false);
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testColor = null;
      _testIcon = null;
      _canPreview = false;
    });

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      setState(() {
        _isTesting = false;
        _testMessage = AppStrings.get('invalid_url', lang);
        _testColor = Colors.redAccent;
        _testIcon = Icons.error_outline_rounded;
      });
      return;
    }

    final lowerUrl = rawUrl.toLowerCase();
    final hasExpiringToken = lowerUrl.contains('sec2(') ||
        lowerUrl.contains('dmcdn.net') ||
        (lowerUrl.contains('token=') && lowerUrl.contains('exp='));

    try {
      final client = http.Client();
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 7));
      final statusCode = streamedResponse.statusCode;
      final contentType = streamedResponse.headers['content-type']?.toLowerCase() ?? '';

      client.close();

      if (!mounted) return;

      if (statusCode == 403) {
        setState(() {
          _isTesting = false;
          _testMessage = AppStrings.get('stream_error_403', lang);
          _testColor = Colors.redAccent;
          _testIcon = Icons.block_rounded;
        });
        return;
      }

      if (statusCode == 404) {
        setState(() {
          _isTesting = false;
          _testMessage = AppStrings.get('stream_error_404', lang);
          _testColor = Colors.redAccent;
          _testIcon = Icons.search_off_rounded;
        });
        return;
      }

      if (contentType.contains('text/html')) {
        setState(() {
          _isTesting = false;
          _testMessage = AppStrings.get('stream_is_webpage', lang);
          _testColor = Colors.orangeAccent;
          _testIcon = Icons.language_rounded;
        });
        return;
      }

      if (hasExpiringToken) {
        setState(() {
          _isTesting = false;
          _testMessage = AppStrings.get('stream_has_temporary_token', lang);
          _testColor = Colors.amber;
          _testIcon = Icons.warning_amber_rounded;
          _canPreview = true;
        });
        return;
      }

      if (statusCode >= 200 && statusCode < 300) {
        setState(() {
          _isTesting = false;
          _testMessage = AppStrings.get('stream_working', lang);
          _testColor = Colors.greenAccent;
          _testIcon = Icons.check_circle_rounded;
          _canPreview = true;
        });
        return;
      }

      setState(() {
        _isTesting = false;
        _testMessage = '${AppStrings.get('stream_failed', lang)} ($statusCode)';
        _testColor = Colors.redAccent;
        _testIcon = Icons.error_outline_rounded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _testMessage = AppStrings.get('stream_failed', lang);
        _testColor = Colors.redAccent;
        _testIcon = Icons.wifi_off_rounded;
      });
    }
  }

  Future<void> _togglePreview() async {
    final rawUrl = _urlController.text.trim();
    if (_isPlayingPreview) {
      await _previewPlayer?.stop();
      if (mounted) setState(() => _isPlayingPreview = false);
    } else {
      _previewPlayer ??= AudioPlayer();
      try {
        if (mounted) setState(() => _isPlayingPreview = true);
        await _previewPlayer!.setUrl(rawUrl, preload: false);
        await _previewPlayer!.play();
      } catch (e) {
        if (mounted) setState(() => _isPlayingPreview = false);
      }
    }
  }

  void _saveStation(String lang) {
    if (_formKey.currentState!.validate()) {
      if (_testIcon == Icons.language_rounded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade900,
            content: Text(AppStrings.get('stream_is_webpage', lang)),
          ),
        );
        return;
      }

      final country = _countryController.text.toLowerCase().trim();
      final lat = double.tryParse(_latController.text) ?? (_capitals[country]?[0] ?? 24.0);
      final lon = double.tryParse(_lonController.text) ?? (_capitals[country]?[1] ?? 45.0);

      if (widget.stationToEdit != null) {
        final updated = widget.stationToEdit!.copyWith(
          name: _nameController.text.trim(),
          country: _countryController.text.trim(),
          streamUrl: _urlController.text.trim(),
          directUrl: _urlController.text.trim(),
          lat: lat,
          lon: lon,
        );
        ref.read(favoritesProvider.notifier).updateStation(widget.stationToEdit!, updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('station_updated', lang))),
        );
      } else {
        final newStation = Station(
          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text.trim(),
          streamUrl: _urlController.text.trim(),
          directUrl: _urlController.text.trim(),
          country: _countryController.text.trim(),
          lat: lat,
          lon: lon,
        );
        ref.read(favoritesProvider.notifier).toggleFavorite(newStation);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('station_added', lang))),
        );
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final isRtl = lang == 'ar';
    final isEditing = widget.stationToEdit != null;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.get(isEditing ? 'edit_station' : 'add_custom_station', lang)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('station_name', lang),
                    prefixIcon: const Icon(Icons.radio_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppStrings.get('field_required', lang) : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('country_label', lang),
                    prefixIcon: const Icon(Icons.public_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? AppStrings.get('field_required', lang) : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('stream_url', lang),
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppStrings.get('field_required', lang);
                    }
                    if (!v.trim().startsWith('http://') && !v.trim().startsWith('https://')) {
                      return 'الرابط يجب أن يبدأ بـ http:// أو https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                // Smart Stream Verifier Button
                Align(
                  alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : () => _testStream(lang),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Icon(Icons.verified_outlined, size: 18),
                    label: Text(
                      _isTesting
                          ? AppStrings.get('testing_stream', lang)
                          : AppStrings.get('test_stream', lang),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: (_testColor ?? Colors.blue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_testColor ?? Colors.blue).withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_testIcon ?? Icons.info_outline, color: _testColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _testMessage!,
                                style: TextStyle(
                                  color: _testColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_canPreview) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _togglePreview,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPlayingPreview ? Colors.redAccent : AppTheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: Icon(_isPlayingPreview ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
                              label: Text(
                                AppStrings.get(_isPlayingPreview ? 'preview_stop' : 'preview_play', lang),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: InputDecoration(
                          labelText: AppStrings.get('lat_optional', lang),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lonController,
                        decoration: InputDecoration(
                          labelText: AppStrings.get('lon_optional', lang),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveStation(lang),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(isEditing ? Icons.save_rounded : Icons.bookmark_add_rounded),
                    label: Text(
                      AppStrings.get(isEditing ? 'save_changes' : 'save_station', lang),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
