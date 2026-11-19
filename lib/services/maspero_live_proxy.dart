import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:myradio1/services/maspero_stream_resolver.dart';
import 'package:myradio1/services/stream_recorder_service.dart';

/// Lightweight in-process local HTTP proxy for streaming Maspero HLS fMP4 live audio
/// as standard, universal ADTS AAC streams on desktop platforms (Windows / Linux).
class MasperoLiveProxy {
  static const String _userAgent = 'Mozilla/5.0 (Android; Mobile)';

  static HttpServer? _server;
  static StreamController<List<int>>? _streamController;
  static Timer? _pollTimer;
  static HttpClient? _pollClient;
  static String? _currentVideoId;
  static bool _isRunning = false;
  static bool _initSegmentFetched = false;
  static final Set<String> _downloadedSegments = <String>{};
  static final Fmp4AacExtractor _extractor = Fmp4AacExtractor();

  static bool get isRunning => _isRunning && _server != null;
  static String? get currentVideoId => _currentVideoId;

  /// Starts or reuses the local streaming proxy for the given Maspero video ID.
  /// Returns the local HTTP streaming URL (e.g. http://127.0.0.1:PORT/maspero_live.aac).
  static Future<String?> getOrStartProxy(String rawUrl) async {
    final videoId = MasperoStreamResolver.extractVideoId(rawUrl);
    if (videoId == null || videoId.isEmpty) return null;

    if (_isRunning && _server != null && _currentVideoId == videoId) {
      return 'http://127.0.0.1:${_server!.port}/maspero_live.aac';
    }

    await stop();

    final childPlaylistUrl = await MasperoStreamResolver.resolveChildPlaylistUrl(videoId);
    if (childPlaylistUrl == null || childPlaylistUrl.isEmpty) {
      return null;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _streamController = StreamController<List<int>>.broadcast();
      _currentVideoId = videoId;
      _isRunning = true;
      _initSegmentFetched = false;
      _downloadedSegments.clear();

      _pollClient = HttpClient();
      _pollClient!.connectionTimeout = const Duration(seconds: 8);
      _pollClient!.findProxy = HttpClient.findProxyFromEnvironment;

      // Handle client requests (Audio Player & Stream Recorder)
      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path != '/maspero_live.aac') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        request.response.headers.set('Content-Type', 'audio/aac');
        request.response.headers.set('Cache-Control', 'no-cache, no-store');
        request.response.headers.set('Connection', 'close');

        try {
          if (_streamController != null && !_streamController!.isClosed) {
            await request.response.addStream(_streamController!.stream);
          }
        } catch (_) {
        } finally {
          try {
            await request.response.close();
          } catch (_) {}
        }
      });

      // Initial playlist poll
      await _pollHlsChunks(childPlaylistUrl);

      // Periodic poll every 2 seconds
      _pollTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
        if (!_isRunning) return;
        _pollHlsChunks(childPlaylistUrl);
      });

      final localUrl = 'http://127.0.0.1:${_server!.port}/maspero_live.aac';
      debugPrint('MasperoLiveProxy started on $localUrl for video $videoId');
      return localUrl;
    } catch (e) {
      debugPrint('Error starting MasperoLiveProxy: $e');
      await stop();
      return null;
    }
  }

  static Future<void> _pollHlsChunks(String playlistUrl) async {
    if (!_isRunning || _pollClient == null || _streamController == null || _streamController!.isClosed) {
      return;
    }

    try {
      final req = await _pollClient!.getUrl(Uri.parse(playlistUrl));
      req.headers.set('User-Agent', _userAgent);
      req.headers.set('priority', 'u=1, i');
      req.headers.set('Accept', '*/*');

      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode != 200 || !_isRunning) return;

      final body = await res.transform(utf8.decoder).join();
      final lines = body.split('\n');
      final baseUri = Uri.parse(playlistUrl);

      String? initUri;
      final mediaSegments = <String>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#EXT-X-MAP:URI="')) {
          final endIdx = trimmed.lastIndexOf('"');
          if (endIdx > 16) {
            initUri = trimmed.substring(16, endIdx);
          }
        } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          mediaSegments.add(trimmed);
        }
      }

      // 1. Fetch init segment if not yet parsed
      if (initUri != null && !_initSegmentFetched && _isRunning) {
        final initBytes = await _fetchChunk(baseUri.resolve(initUri));
        if (initBytes != null && _isRunning) {
          _extractor.parseInitSegment(initBytes);
          _initSegmentFetched = true;
        }
      }

      // 2. Fetch media segments and push ADTS AAC frames
      for (final seg in mediaSegments) {
        if (!_isRunning) break;
        final segUri = baseUri.resolve(seg);
        final segKey = segUri.toString();

        if (!_downloadedSegments.contains(segKey)) {
          _downloadedSegments.add(segKey);

          // On first run, skip older backlog to prevent initial latency
          if (_downloadedSegments.length == 1 && mediaSegments.length > 2) {
            final idx = mediaSegments.indexOf(seg);
            if (idx < mediaSegments.length - 2) {
              continue;
            }
          }

          final chunkBytes = await _fetchChunk(segUri);
          if (chunkBytes != null && _isRunning && _streamController != null && !_streamController!.isClosed) {
            final adtsFrames = _extractor.extractAdtsFromM4s(chunkBytes);
            if (adtsFrames != null && adtsFrames.isNotEmpty) {
              _streamController!.add(adtsFrames);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('MasperoLiveProxy poll error: $e');
    }
  }

  static Future<Uint8List?> _fetchChunk(Uri uri) async {
    if (!_isRunning || _pollClient == null) return null;
    try {
      final req = await _pollClient!.getUrl(uri);
      req.headers.set('User-Agent', _userAgent);
      req.headers.set('priority', 'u=1, i');
      req.headers.set('Accept', '*/*');

      final res = await req.close().timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && _isRunning) {
        final builder = await res.fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d));
        return builder.takeBytes();
      }
    } catch (_) {}
    return null;
  }

  /// Stops the proxy and releases all resources.
  static Future<void> stop() async {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;

    _pollClient?.close(force: true);
    _pollClient = null;

    if (_streamController != null && !_streamController!.isClosed) {
      try {
        await _streamController!.close();
      } catch (_) {}
    }
    _streamController = null;

    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
    }
    _server = null;
    _currentVideoId = null;
    _initSegmentFetched = false;
    _downloadedSegments.clear();
  }
}
