import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _nameController.dispose();
    _countryController.dispose();
    _urlController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _saveStation(String lang) {
    if (_formKey.currentState!.validate()) {
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
