import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service responsible for recording any internet radio stream
/// supporting both HLS (.m3u8 with fMP4/TS/AAC) and Direct streams (MP3/AAC/OGG/Shoutcast).
class StreamRecorderService {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  bool _isRecording = false;
  IOSink? _fileSink;
  File? _currentFile;
  Timer? _hlsPollingTimer;
  http.Client? _httpClient;
  StreamSubscription? _directSubscription;
  Socket? _rawSocket;

  // HLS tracking state
  final Set<String> _downloadedSegmentUris = <String>{};
  bool _initSegmentWritten = false;
  bool _isFetchingHls = false;

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFile?.path;

  static String sanitizePrefix(String? stationName) {
    if (stationName == null || stationName.trim().isEmpty) return 'Atheer_Live';
    final ascii = stationName
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (ascii.length >= 2) {
      return ascii.length > 20 ? ascii.substring(0, 20) : ascii;
    }
    return 'Atheer_Live';
  }

  /// Probes the stream to determine if it is HLS or direct stream,
  /// and discovers the best file extension (.mp3, .m4a, .aac, .ogg, etc.).
  static Future<_StreamMeta> _probeStream(String rawUrl) async {
    final cleanUrl = rawUrl.split('#').first.trim();
    final uri = Uri.parse(cleanUrl);

    // Check URL pattern first
    final pathLower = uri.path.toLowerCase();
    if (pathLower.endsWith('.m3u8') || pathLower.contains('/hls/')) {
      return _StreamMeta(isHls: true, cleanUrl: cleanUrl, extension: 'm4a');
    }

    // Probe via HTTP request with HEAD or initial GET
    try {
      final client = http.Client();
      final req = http.Request('GET', uri)
        ..headers['User-Agent'] = _userAgent
        ..headers['Accept'] = '*/*'
        ..headers['Icy-MetaData'] = '0'
        ..followRedirects = true
        ..maxRedirects = 5;

      final res = await client.send(req).timeout(const Duration(seconds: 8));
      final ctype = (res.headers['content-type'] ?? '').toLowerCase();

      client.close();

      if (ctype.contains('mpegurl') || ctype.contains('m3u8')) {
        return _StreamMeta(isHls: true, cleanUrl: cleanUrl, extension: 'm4a');
      }

      String ext = 'mp3';
      if (ctype.contains('audio/aac') || ctype.contains('audio/aacp')) {
        ext = 'aac';
      } else if (ctype.contains('audio/mp4') || ctype.contains('audio/x-m4a')) {
        ext = 'm4a';
      } else if (ctype.contains('audio/ogg') || ctype.contains('application/ogg')) {
        ext = 'ogg';
      } else if (pathLower.endsWith('.aac')) {
        ext = 'aac';
      } else if (pathLower.endsWith('.m4a')) {
        ext = 'm4a';
      } else if (pathLower.endsWith('.ogg')) {
        ext = 'ogg';
      }

      return _StreamMeta(isHls: false, cleanUrl: cleanUrl, extension: ext);
    } catch (_) {
      // Fallback: check extension from URL
      final isHls = pathLower.endsWith('.m3u8');
      return _StreamMeta(
        isHls: isHls,
        cleanUrl: cleanUrl,
        extension: isHls ? 'm4a' : 'mp3',
      );
    }
  }

  /// Starts recording a stream (either HLS or direct).
  Future<String?> startRecording({
    required String streamUrl,
    String? stationName,
  }) async {
    if (_isRecording) {
      await stopRecording();
    }

    try {
      final Directory? musicDir = await getExternalStorageDirectory();
      if (musicDir == null) return null;
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final meta = await _probeStream(streamUrl);
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final prefix = sanitizePrefix(stationName);

      final filePath = '${musicDir.path}/${prefix}_$stamp.${meta.extension}';
      _currentFile = File(filePath);
      _fileSink = _currentFile!.openWrite(mode: FileMode.writeOnly);
      _isRecording = true;

      _httpClient = http.Client();

      if (meta.isHls) {
        await _startHlsRecording(meta.cleanUrl);
      } else {
        await _startDirectRecording(meta.cleanUrl);
      }

      return filePath;
    } catch (e) {
      await stopRecording();
      return null;
    }
  }

  /// Handles recording of HLS (.m3u8) streams by fetching playlist chunks sequentially.
  Future<void> _startHlsRecording(String playlistUrl) async {
    _downloadedSegmentUris.clear();
    _initSegmentWritten = false;

    // Do immediate first fetch
    await _pollHlsPlaylist(playlistUrl);

    // Periodically poll for new segments every 2.5 seconds
    _hlsPollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!_isRecording) return;
      _pollHlsPlaylist(playlistUrl);
    });
  }

  Future<void> _pollHlsPlaylist(String playlistUrl) async {
    if (_isFetchingHls || !_isRecording) return;
    _isFetchingHls = true;

    try {
      final uri = Uri.parse(playlistUrl);
      final response = await _httpClient!.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200 || !_isRecording) {
        _isFetchingHls = false;
        return;
      }

      final body = response.body;
      final lines = body.split('\n');

      // Check if this is a Master Playlist (contains other playlists)
      String? childPlaylistUrl;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          if (trimmed.contains('.m3u8')) {
            childPlaylistUrl = uri.resolve(trimmed).toString();
            break;
          }
        }
      }

      if (childPlaylistUrl != null) {
        // Switch to the media playlist
        _isFetchingHls = false;
        await _pollHlsPlaylist(childPlaylistUrl);
        return;
      }

      // Check for fMP4 init segment: #EXT-X-MAP:URI="init.mp4"
      String? initSegmentUri;
      final mediaSegmentUris = <String>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#EXT-X-MAP:URI="')) {
          final endIdx = trimmed.lastIndexOf('"');
          if (endIdx > 16) {
            initSegmentUri = trimmed.substring(16, endIdx);
          }
        } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          mediaSegmentUris.add(trimmed);
        }
      }

      // 1. Download initialization segment if present and not yet written
      if (initSegmentUri != null && !_initSegmentWritten && _isRecording) {
        final resolvedInit = uri.resolve(initSegmentUri);
        final initBytes = await _fetchChunk(resolvedInit);
        if (initBytes != null && _isRecording) {
          _fileSink?.add(initBytes);
          _initSegmentWritten = true;
        }
      }

      // 2. Download any new media segments
      for (final seg in mediaSegmentUris) {
        if (!_isRecording) break;
        final resolvedSeg = uri.resolve(seg);
        final segKey = resolvedSeg.toString();

        if (!_downloadedSegmentUris.contains(segKey)) {
          _downloadedSegmentUris.add(segKey);

          // If this is our very first poll and there are many historical segments,
          // only grab the last 2 segments to avoid huge back-log delay:
          if (_downloadedSegmentUris.length == 1 && mediaSegmentUris.length > 3) {
            final idx = mediaSegmentUris.indexOf(seg);
            if (idx < mediaSegmentUris.length - 2) {
              continue;
            }
          }

          final chunkBytes = await _fetchChunk(resolvedSeg);
          if (chunkBytes != null && _isRecording) {
            _fileSink?.add(chunkBytes);
          }
        }
      }
    } catch (_) {
      // Ignore transient network errors during live polling; will retry next tick
    } finally {
      _isFetchingHls = false;
    }
  }

  Future<Uint8List?> _fetchChunk(Uri uri) async {
    try {
      final res = await _httpClient!.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Handles recording of direct HTTP/Icecast/Shoutcast streams.
  Future<void> _startDirectRecording(String streamUrl) async {
    final uri = Uri.parse(streamUrl);

    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = _userAgent
        ..headers['Accept'] = '*/*'
        ..headers['Icy-MetaData'] = '0'
        ..followRedirects = true
        ..maxRedirects = 8;

      final streamedResponse = await _httpClient!.send(request).timeout(const Duration(seconds: 12));

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 400) {
        _directSubscription = streamedResponse.stream.listen(
          (chunk) {
            if (_isRecording) {
              _fileSink?.add(chunk);
            }
          },
          onError: (_) => stopRecording(),
          onDone: () => stopRecording(),
          cancelOnError: true,
        );
        return;
      }
    } catch (_) {
      // Standard HttpClient failed (e.g. Shoutcast v1 ICY 200 OK), try raw socket fallback
    }

    // Raw Socket Fallback for Shoutcast v1 servers that send non-standard 'ICY 200 OK'
    await _startRawSocketFallback(uri);
  }

  Future<void> _startRawSocketFallback(Uri uri) async {
    try {
      final host = uri.host;
      final port = uri.port > 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final isSecure = uri.scheme == 'https';

      if (isSecure) {
        _rawSocket = await SecureSocket.connect(host, port, timeout: const Duration(seconds: 10));
      } else {
        _rawSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      }

      final path = uri.hasQuery ? '${uri.path}?${uri.query}' : (uri.path.isEmpty ? '/' : uri.path);
      final reqStr =
          'GET $path HTTP/1.0\r\nHost: $host\r\nUser-Agent: $_userAgent\r\nAccept: */*\r\nIcy-MetaData: 0\r\nConnection: close\r\n\r\n';
      _rawSocket!.write(reqStr);

      bool headersParsed = false;
      final headerBuffer = <int>[];

      _directSubscription = _rawSocket!.listen(
        (data) {
          if (!_isRecording) return;

          if (!headersParsed) {
            headerBuffer.addAll(data);
            // Search for end of headers: \r\n\r\n (13, 10, 13, 10)
            int bodyStart = -1;
            for (int i = 0; i < headerBuffer.length - 3; i++) {
              if (headerBuffer[i] == 13 &&
                  headerBuffer[i + 1] == 10 &&
                  headerBuffer[i + 2] == 13 &&
                  headerBuffer[i + 3] == 10) {
                bodyStart = i + 4;
                break;
              }
            }

            if (bodyStart != -1) {
              headersParsed = true;
              if (bodyStart < headerBuffer.length) {
                _fileSink?.add(headerBuffer.sublist(bodyStart));
              }
            }
          } else {
            _fileSink?.add(data);
          }
        },
        onError: (_) => stopRecording(),
        onDone: () => stopRecording(),
        cancelOnError: true,
      );
    } catch (e) {
      await stopRecording();
    }
  }

  /// Stops any ongoing recording safely and flushes file sink.
  Future<void> stopRecording() async {
    _isRecording = false;
    _hlsPollingTimer?.cancel();
    _hlsPollingTimer = null;

    await _directSubscription?.cancel();
    _directSubscription = null;

    try {
      _rawSocket?.destroy();
    } catch (_) {}
    _rawSocket = null;

    _httpClient?.close();
    _httpClient = null;

    try {
      await _fileSink?.flush();
      await _fileSink?.close();
    } catch (_) {}
    _fileSink = null;
  }
}

class _StreamMeta {
  final bool isHls;
  final String cleanUrl;
  final String extension;

  const _StreamMeta({
    required this.isHls,
    required this.cleanUrl,
    required this.extension,
  });
}
