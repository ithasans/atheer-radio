class Station {
  final String id;
  final String name;
  final String streamUrl;
  final String? directUrl;
  final String? favicon;
  final String? country;
  final String? countryCode;
  final String? tags;
  final String? language;
  final String? codec;
  final int? bitrate;
  final double? lat;
  final double? lon;

  const Station({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.directUrl,
    this.favicon,
    this.country,
    this.countryCode,
    this.tags,
    this.language,
    this.codec,
    this.bitrate,
    this.lat,
    this.lon,
  });

  String get playableUrl => (directUrl != null && directUrl!.isNotEmpty) ? directUrl! : streamUrl;

  Station copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? directUrl,
    String? favicon,
    String? country,
    String? countryCode,
    String? tags,
    String? language,
    String? codec,
    int? bitrate,
    double? lat,
    double? lon,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      directUrl: directUrl ?? this.directUrl,
      favicon: favicon ?? this.favicon,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      tags: tags ?? this.tags,
      language: language ?? this.language,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }

  List<String> get tagList {
    if (tags == null || tags!.trim().isEmpty) return [];
    return tags!
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();
  }

  Map<String, dynamic> toMap() => {
    'stationuuid': id,
    'name': name,
    'url': streamUrl,
    'url_resolved': directUrl ?? streamUrl,
    'favicon': favicon,
    'country': country,
    'countrycode': countryCode,
    'tags': tags,
    'language': language,
    'codec': codec,
    'bitrate': bitrate,
    'geo_lat': lat,
    'geo_long': lon,
  };

  factory Station.fromMap(Map<String, dynamic> map) {
    double? parsedLat = double.tryParse(map['geo_lat']?.toString() ?? '') ??
        (map['lat'] is num ? (map['lat'] as num).toDouble() : null);
    double? parsedLon = double.tryParse(map['geo_long']?.toString() ?? '') ??
        (map['lon'] is num ? (map['lon'] as num).toDouble() : null);

    return Station(
      id: map['stationuuid']?.toString() ?? map['id']?.toString() ?? map['url']?.toString() ?? '',
      name: (map['name']?.toString() ?? 'محطة غير معروفة').trim(),
      streamUrl: map['url']?.toString() ?? '',
      directUrl: map['url_resolved']?.toString(),
      favicon: (map['favicon']?.toString().startsWith('http') ?? false) ? map['favicon'].toString() : null,
      country: map['country']?.toString(),
      countryCode: map['countrycode']?.toString(),
      tags: map['tags']?.toString(),
      language: map['language']?.toString(),
      codec: map['codec']?.toString(),
      bitrate: int.tryParse(map['bitrate']?.toString() ?? ''),
      lat: parsedLat,
      lon: parsedLon,
    );
  }
}
