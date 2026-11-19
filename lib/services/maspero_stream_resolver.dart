import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:myradio1/models/station.dart';
import 'package:myradio1/services/maspero_live_proxy.dart';

class _CachedResolvedStream {
  final String url;
  final DateTime resolvedAt;

  _CachedResolvedStream(this.url) : resolvedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(resolvedAt).inMinutes >= 20;
}

/// Service to resolve live audio HLS manifests for Egyptian Maspero (National Media Authority) stations.
class MasperoStreamResolver {
  static final Map<String, _CachedResolvedStream> _cache = {};

  static const List<Map<String, String>> _masperoStationsMeta = [
    {
      'id': 'x8n6drt',
      'name': 'إذاعة الشرق الأوسط',
      'favicon': 'https://s2.dmcdn.net/v/V9o8v1g_ePiHJAqHi/x360',
      'tags': 'maspero, egyptian, live, news, cultural',
    },
    {
      'id': 'x8n6dqq',
      'name': 'إذاعة صوت العرب',
      'favicon': 'https://s2.dmcdn.net/v/V9o8I1g_YkbopXWNW/x360',
      'tags': 'maspero, egyptian, live, arab, cultural',
    },
    {
      'id': 'x8n6dt3',
      'name': 'إذاعة البرنامج العام',
      'favicon': 'https://s2.dmcdn.net/v/V9o9d1g-qmI_mGPYJ/x360',
      'tags': 'maspero, egyptian, live, general, news',
    },
    {
      'id': 'x8n6dzo',
      'name': 'إذاعة الشباب والرياضة',
      'favicon': 'https://s1.dmcdn.net/v/V9oDK1g_Nv3RcAO-v/x360',
      'tags': 'maspero, egyptian, live, sports, youth',
    },
    {
      'id': 'x8n6dyz',
      'name': 'إذاعة الأغاني',
      'favicon': 'https://s1.dmcdn.net/v/V9oCx1g-qn4R9gSJV/x360',
      'tags': 'maspero, egyptian, live, classic, music',
    },
    {
      'id': 'x8n6dpk',
      'name': 'إذاعة راديو مصر 88.7',
      'favicon': 'https://s1.dmcdn.net/v/V9o7e1g-qmyIMq8Sx/x360',
      'tags': 'maspero, egyptian, live, news, radiomasr',
    },
    {
      'id': 'x8n6ebs',
      'name': 'إذاعة القاهرة الكبرى',
      'favicon': 'https://s2.dmcdn.net/v/V9oK81g_2OW0Vl_TY/x360',
      'tags': 'maspero, egyptian, live, local, cairo',
    },
    {
      'id': 'x8n6eci',
      'name': 'إذاعة البرنامج الثقافي ودراما',
      'favicon': 'https://s2.dmcdn.net/v/V9oKY1g-qmxDBIyy_/x360',
      'tags': 'maspero, egyptian, live, culture, drama',
    },
    {
      'id': 'x8n6e6w',
      'name': 'إذاعة البرنامج الأوروبي',
      'favicon': 'https://s1.dmcdn.net/v/V9oHO1g-qmwpXoS_d/x360',
      'tags': 'maspero, egyptian, live, foreign, european',
    },
  ];

  /// Returns curated List of Maspero stations.
  static List<Station> getMasperoStations() {
    return _masperoStationsMeta.map((meta) {
      final vid = meta['id']!;
      return Station(
        id: 'maspero_$vid',
        name: meta['name']!,
        streamUrl: 'maspero://$vid',
        favicon: meta['favicon'],
        country: 'مصر',
        countryCode: 'EG',
        tags: meta['tags'],
        codec: 'AAC',
        bitrate: 64,
      );
    }).toList();
  }

  /// Determines if a URL represents a Maspero station.
  static bool isMasperoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.startsWith('maspero://')) return true;
    for (final meta in _masperoStationsMeta) {
      if (lower.contains(meta['id']!)) return true;
    }
    return false;
  }

  /// Extracts the video identifier from a Maspero stream URL.
  static String? extractVideoId(String url) {
    final clean = url.trim();
    if (clean.startsWith('maspero://')) {
      return clean.substring('maspero://'.length).split('/').first.split('?').first.trim();
    }
    for (final meta in _masperoStationsMeta) {
      if (clean.contains(meta['id']!)) {
        return meta['id']!;
      }
    }
    final match = RegExp(r'[xX][0-9a-zA-Z]{6}').firstMatch(clean);
    return match?.group(0);
  }

  /// Resolves the URL dynamically to a fresh direct audio HLS URL or local proxy URL.
  /// On desktop (Windows / Linux), streams through MasperoLiveProxy for universal ADTS AAC playback.
  /// On mobile (Android / iOS), returns the direct HLS stream URL for native ExoPlayer / AVPlayer playback.
  static Future<String> resolveStreamUrl(String rawUrl) async {
    if (!isMasperoUrl(rawUrl)) {
      return rawUrl;
    }

    final videoId = extractVideoId(rawUrl);
    if (videoId == null || videoId.isEmpty) {
      return rawUrl;
    }

    if (Platform.isWindows || Platform.isLinux) {
      final proxyUrl = await MasperoLiveProxy.getOrStartProxy(rawUrl);
      if (proxyUrl != null && proxyUrl.isNotEmpty) {
        return proxyUrl;
      }
    }

    // Check memory cache
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final resolved = await _resolveDirect(videoId);
      if (resolved != null && resolved.isNotEmpty) {
        _cache[videoId] = _CachedResolvedStream(resolved);
        return resolved;
      }
    } catch (e) {
      debugPrint('MasperoStreamResolver error: $e');
    }

    return cached?.url ?? rawUrl;
  }

  /// Resolves the raw HLS child playlist URL (used by Mobile and by MasperoLiveProxy on Desktop).
  static Future<String?> resolveChildPlaylistUrl(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }
    final resolved = await _resolveDirect(videoId);
    if (resolved != null && resolved.isNotEmpty) {
      _cache[videoId] = _CachedResolvedStream(resolved);
      return resolved;
    }
    return null;
  }

  /// Direct cross-platform resolution using Dart HttpClient.
  /// Works reliably on Windows, Android, Linux, macOS and iOS without external processes.
  static Future<String?> _resolveDirect(String videoId) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      client.findProxy = HttpClient.findProxyFromEnvironment;

      final metaUri = Uri.parse(
        'https://www.dailymotion.com/player/metadata/video/$videoId?app=com.dailymotion.neon',
      );
      final metaReq = await client.getUrl(metaUri);
      metaReq.headers.set('User-Agent', 'Mozilla/5.0 (Android; Mobile)');
      metaReq.headers.set('priority', 'u=1, i');
      metaReq.headers.set('Accept', '*/*');

      final metaRes = await metaReq.close().timeout(const Duration(seconds: 8));
      if (metaRes.statusCode == 200) {
        final metaBody = await metaRes.transform(utf8.decoder).join();
        final metaJson = json.decode(metaBody) as Map<String, dynamic>;
        final m3u8Url = metaJson['qualities']?['auto']?[0]?['url']?.toString();
        if (m3u8Url != null) {
          final m3u8Req = await client.getUrl(Uri.parse(m3u8Url));
          m3u8Req.headers.set('User-Agent', 'Mozilla/5.0 (Android; Mobile)');
          m3u8Req.headers.set('priority', 'u=1, i');
          m3u8Req.headers.set('Accept', '*/*');
          for (final c in metaRes.cookies) {
            m3u8Req.cookies.add(Cookie(c.name, c.value));
          }
          final m3u8Res = await m3u8Req.close().timeout(const Duration(seconds: 8));
          if (m3u8Res.statusCode == 200) {
            final m3u8Body = await m3u8Res.transform(utf8.decoder).join();
            final match = RegExp(r'URI="([^"]+)"').firstMatch(m3u8Body);
            if (match != null) {
              final directAudio = match.group(1)!.split('#').first.trim();
              return directAudio;
            }
          }
          return m3u8Url.split('#').first.trim();
        }
      }
    } catch (e) {
      debugPrint('Maspero direct resolution error: $e');
    } finally {
      client?.close();
    }
    return null;
  }
}
