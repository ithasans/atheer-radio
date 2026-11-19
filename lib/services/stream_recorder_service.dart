import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myradio1/services/maspero_stream_resolver.dart';

/// Helper to extract raw AAC frames from fragmented MP4 (.m4s) chunks
/// and wrap each frame with a standard 7-byte ADTS header for immediate, universal playback.
class Fmp4AacExtractor {
  int profile = 2; // AAC LC
  int freqIndex = 4; // 44100 Hz
  int chanCfg = 2; // Stereo
  bool hasConfig = false;

  void parseInitSegment(Uint8List data) {
    // 1. Try 'esds' and extract AudioSpecificConfig
    final esdsPos = _findPattern(data, [0x65, 0x73, 0x64, 0x73]); // 'esds'
    if (esdsPos != -1 && esdsPos + 8 < data.length) {
      for (int i = esdsPos + 4; i < esdsPos + 60 && i + 3 < data.length; i++) {
        if (data[i] == 0x05) {
          int offset = i + 1;
          while (offset < data.length && (data[offset] & 0x80) != 0) {
            offset++;
          }
          offset++; // skip last length byte
          if (offset + 1 < data.length) {
            final b0 = data[offset];
            final b1 = data[offset + 1];
            final p = (b0 >> 3) & 0x1F;
            final f = ((b0 & 0x07) << 1) | ((b1 >> 7) & 0x01);
            final c = (b1 >> 3) & 0x0F;
            if (f < 13 && c > 0) {
              profile = p;
              freqIndex = f;
              chanCfg = c;
              hasConfig = true;
              return;
            }
          }
        }
      }
    }

    // 2. Fallback: Parse 'mp4a' box directly
    final mp4aPos = _findPattern(data, [0x6D, 0x70, 0x34, 0x61]); // 'mp4a'
    if (mp4aPos != -1 && mp4aPos + 30 < data.length) {
      final channels = (data[mp4aPos + 20] << 8) | data[mp4aPos + 21];
      final sampleRate = (data[mp4aPos + 28] << 8) | data[mp4aPos + 29];
      if (channels > 0 && channels <= 8) chanCfg = channels;
      if (sampleRate > 0) {
        freqIndex = _sampleRateToFreqIndex(sampleRate);
      }
      profile = 2; // AAC LC default
      hasConfig = true;
    }
  }

  static int _sampleRateToFreqIndex(int rate) {
    switch (rate) {
      case 96000: return 0;
      case 88200: return 1;
      case 64000: return 2;
      case 48000: return 3;
      case 44100: return 4;
      case 32000: return 5;
      case 24000: return 6;
      case 22050: return 7;
      case 16000: return 8;
      case 12000: return 9;
      case 11025: return 10;
      case 8000:  return 11;
      case 7350:  return 12;
      default:
        if (rate >= 46000) return 3;
        return 4;
    }
  }

  Uint8List? extractAdtsFromM4s(Uint8List data) {
    final trunPos = _findPattern(data, [0x74, 0x72, 0x75, 0x6E]); // 'trun'
    if (trunPos == -1 || trunPos + 12 > data.length) return null;

    final flags = (data[trunPos + 5] << 16) | (data[trunPos + 6] << 8) | data[trunPos + 7];
    final sampleCount = (data[trunPos + 8] << 24) |
        (data[trunPos + 9] << 16) |
        (data[trunPos + 10] << 8) |
        data[trunPos + 11];

    if (sampleCount <= 0 || sampleCount > 5000) return null;

    int idx = trunPos + 12;
    int? dataOffset;
    if ((flags & 0x01) != 0) {
      if (idx + 4 > data.length) return null;
      dataOffset = (data[idx] << 24) | (data[idx + 1] << 16) | (data[idx + 2] << 8) | data[idx + 3];
      idx += 4;
    }
    if ((flags & 0x04) != 0) idx += 4;

    final sampleSizes = <int>[];
    for (int i = 0; i < sampleCount; i++) {
      if (idx >= data.length) break;
      if ((flags & 0x100) != 0) idx += 4;
      if ((flags & 0x200) != 0) {
        if (idx + 4 <= data.length) {
          final sz = (data[idx] << 24) | (data[idx + 1] << 16) | (data[idx + 2] << 8) | data[idx + 3];
          sampleSizes.add(sz);
          idx += 4;
        }
      }
      if ((flags & 0x400) != 0) idx += 4;
      if ((flags & 0x800) != 0) idx += 4;
    }

    // Fallback to default_sample_size in tfhd if sample_size was not in trun
    if (sampleSizes.isEmpty) {
      final tfhdPos = _findPattern(data, [0x74, 0x66, 0x68, 0x64]); // 'tfhd'
      if (tfhdPos != -1 && tfhdPos + 12 < data.length) {
        final tfFlags = (data[tfhdPos + 5] << 16) | (data[tfhdPos + 6] << 8) | data[tfhdPos + 7];
        int tfIdx = tfhdPos + 12;
        if ((tfFlags & 0x01) != 0) tfIdx += 8;
        if ((tfFlags & 0x02) != 0) tfIdx += 4;
        if ((tfFlags & 0x08) != 0) tfIdx += 4;
        if ((tfFlags & 0x10) != 0 && tfIdx + 4 <= data.length) {
          final defSize = (data[tfIdx] << 24) | (data[tfIdx + 1] << 16) | (data[tfIdx + 2] << 8) | data[tfIdx + 3];
          if (defSize > 0) {
            for (int i = 0; i < sampleCount; i++) {
              sampleSizes.add(defSize);
            }
          }
        }
      }
    }

    if (sampleSizes.isEmpty) return null;

    final mdatPos = _findPattern(data, [0x6D, 0x64, 0x61, 0x74]); // 'mdat'
    if (mdatPos == -1) return null;

    int payloadOffset;
    if (dataOffset != null) {
      final moofPos = _findPattern(data, [0x6D, 0x6F, 0x6F, 0x66]); // 'moof'
      if (moofPos != -1) {
        final moofStart = moofPos >= 4 ? moofPos - 4 : 0;
        payloadOffset = moofStart + dataOffset;
      } else {
        payloadOffset = mdatPos + 4;
      }
    } else {
      final is64Bit = (mdatPos >= 4 &&
          data[mdatPos - 4] == 0 &&
          data[mdatPos - 3] == 0 &&
          data[mdatPos - 2] == 0 &&
          data[mdatPos - 1] == 1);
      payloadOffset = mdatPos + (is64Bit ? 12 : 4);
    }

    if (payloadOffset >= data.length) return null;

    final builder = BytesBuilder(copy: false);

    for (int i = 0; i < sampleSizes.length; i++) {
      final sz = sampleSizes[i];
      if (payloadOffset + sz > data.length) break;

      final frameLen = sz + 7;
      final hdr = Uint8List(7);
      hdr[0] = 0xFF;
      hdr[1] = 0xF1; // MPEG-4, Layer 0, no CRC
      hdr[2] = (((profile - 1) & 0x3) << 6) | ((freqIndex & 0xF) << 2) | ((chanCfg >> 2) & 0x1);
      hdr[3] = ((chanCfg & 0x3) << 6) | ((frameLen >> 11) & 0x3);
      hdr[4] = (frameLen >> 3) & 0xFF;
      hdr[5] = ((frameLen & 7) << 5) | 0x1F;
      hdr[6] = 0xFC;

      builder.add(hdr);
      builder.add(Uint8List.sublistView(data, payloadOffset, payloadOffset + sz));
      payloadOffset += sz;
    }

    final result = builder.takeBytes();
    return result.isNotEmpty ? result : null;
  }

  static int _findPattern(Uint8List data, List<int> pattern) {
    if (data.length < pattern.length) return -1;
    final end = data.length - pattern.length;
    for (int i = 0; i <= end; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}

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
  final Fmp4AacExtractor _fmp4Extractor = Fmp4AacExtractor();
  bool _initSegmentFetched = false;
  bool _isFetchingHls = false;

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFile?.path;

  static String sanitizePrefix(String? stationName) {
    if (stationName == null || stationName.trim().isEmpty) return 'Atheer_Live';
    // Remove characters illegal in file paths: / \ : * ? " < > | and control chars
    var clean = stationName.replaceAll(RegExp(r'[\x00-\x1F/\\:*?"<>|]'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    clean = clean.replaceAll(RegExp(r'[.\s]+$'), '').trim();
    if (clean.length > 50) {
      clean = clean.substring(0, 50).trim();
    }
    return clean.isNotEmpty ? clean : 'Atheer_Live';
  }

  static const String customRecordingsDirKey = 'custom_recordings_dir';

  /// Gets any user-selected custom directory path from SharedPreferences.
  static Future<String?> getCustomRecordingsDirectoryPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(customRecordingsDirKey);
      if (path != null && path.trim().isNotEmpty) {
        return path.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Sets or clears a user-selected custom directory for recordings.
  static Future<bool> setCustomRecordingsDirectory(String? path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path == null || path.trim().isEmpty) {
        await prefs.remove(customRecordingsDirKey);
        return true;
      }
      final dir = Directory(path.trim());
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await prefs.setString(customRecordingsDirKey, dir.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens native Windows FolderBrowserDialog to pick a directory visually.
  static Future<String?> pickFolderOnWindows() async {
    if (!Platform.isWindows) return null;
    try {
      const script = r"""
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = 'اختر مجلد حفظ تسجيلات البث المباشر'
$dialog.ShowNewFolderButton = $true
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output $dialog.SelectedPath
}
""";
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-STA',
        '-Command',
        script,
      ], stdoutEncoding: utf8);

      final out = res.stdout.toString().trim();
      if (out.isNotEmpty && Directory(out).existsSync()) {
        return out;
      }
    } catch (e) {
      debugPrint('Error picking folder via PowerShell: $e');
    }
    return null;
  }

  /// Returns a valid, platform-appropriate directory for saving audio recordings.
  /// On Android: Uses external storage directory (or app documents if unavailable).
  /// On Windows: Uses user-selected folder if set, otherwise Documents\AtheerRadio\Recordings.
  /// On macOS/Linux: Uses user's Documents/AtheerRadio/Recordings directory.
  static Future<Directory?> getRecordingsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final Directory? musicDir = await getExternalStorageDirectory();
        if (musicDir != null) {
          if (!await musicDir.exists()) {
            await musicDir.create(recursive: true);
          }
          return musicDir;
        }
      }

      if (Platform.isWindows) {
        // 1. Check if user configured a custom directory
        final customPath = await getCustomRecordingsDirectoryPath();
        if (customPath != null) {
          final customDir = Directory(customPath);
          if (await customDir.exists()) {
            return customDir;
          } else {
            try {
              await customDir.create(recursive: true);
              return customDir;
            } catch (_) {}
          }
        }

        // 2. Default to Documents\AtheerRadio\Recordings
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null && userProfile.trim().isNotEmpty) {
          final dir = Directory(
            '$userProfile${Platform.pathSeparator}Documents${Platform.pathSeparator}AtheerRadio${Platform.pathSeparator}Recordings',
          );
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      }

      final baseDir = await getApplicationDocumentsDirectory();
      final radioDir = Directory(
        '${baseDir.path}${Platform.pathSeparator}AtheerRadio${Platform.pathSeparator}Recordings',
      );
      if (!await radioDir.exists()) {
        await radioDir.create(recursive: true);
      }
      return radioDir;
    } catch (_) {
      try {
        if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'] ?? 'C:';
          final dir = Directory('$userProfile\\AtheerRadio\\Recordings');
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        }
        final fallbackDir = await getApplicationSupportDirectory();
        final radioDir = Directory(
          '${fallbackDir.path}${Platform.pathSeparator}Recordings',
        );
        if (!await radioDir.exists()) {
          await radioDir.create(recursive: true);
        }
        return radioDir;
      } catch (_) {
        return null;
      }
    }
  }

  /// Probes the stream to determine if it is HLS or direct stream,
  /// and discovers the best file extension (.mp3, .aac, .ogg, etc.).
  static Future<_StreamMeta> _probeStream(String rawUrl) async {
    final cleanUrl = rawUrl.split('#').first.trim();
    final uri = Uri.parse(cleanUrl);

    final pathLower = uri.path.toLowerCase();
    if (pathLower.endsWith('.m3u8') || pathLower.contains('/hls/')) {
      return _StreamMeta(isHls: true, cleanUrl: cleanUrl, extension: 'aac');
    }

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
        return _StreamMeta(isHls: true, cleanUrl: cleanUrl, extension: 'aac');
      }

      String ext = 'mp3';
      if (ctype.contains('audio/aac') || ctype.contains('audio/aacp')) {
        ext = 'aac';
      } else if (ctype.contains('audio/mp4') || ctype.contains('audio/x-m4a')) {
        ext = 'aac';
      } else if (ctype.contains('audio/ogg') || ctype.contains('application/ogg')) {
        ext = 'ogg';
      } else if (pathLower.endsWith('.aac')) {
        ext = 'aac';
      } else if (pathLower.endsWith('.m4a')) {
        ext = 'aac';
      } else if (pathLower.endsWith('.ogg')) {
        ext = 'ogg';
      }

      return _StreamMeta(isHls: false, cleanUrl: cleanUrl, extension: ext);
    } catch (_) {
      final isHls = pathLower.endsWith('.m3u8');
      return _StreamMeta(
        isHls: isHls,
        cleanUrl: cleanUrl,
        extension: isHls ? 'aac' : 'mp3',
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
      final Directory? musicDir = await getRecordingsDirectory();
      if (musicDir == null) return null;
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final effectiveUrl = await MasperoStreamResolver.resolveStreamUrl(streamUrl);
      final meta = await _probeStream(effectiveUrl);
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final prefix = sanitizePrefix(stationName);

      final filePath =
          '${musicDir.path}${Platform.pathSeparator}${prefix}_$stamp.${meta.extension}';
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

  Future<void> _startHlsRecording(String playlistUrl) async {
    _downloadedSegmentUris.clear();
    _initSegmentFetched = false;

    await _pollHlsPlaylist(playlistUrl);

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
        _isFetchingHls = false;
        await _pollHlsPlaylist(childPlaylistUrl);
        return;
      }

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

      if (initSegmentUri != null && !_initSegmentFetched && _isRecording) {
        final resolvedInit = uri.resolve(initSegmentUri);
        final initBytes = await _fetchChunk(resolvedInit);
        if (initBytes != null && _isRecording) {
          _fmp4Extractor.parseInitSegment(initBytes);
          _initSegmentFetched = true;
        }
      }

      for (final seg in mediaSegmentUris) {
        if (!_isRecording) break;
        final resolvedSeg = uri.resolve(seg);
        final segKey = resolvedSeg.toString();

        if (!_downloadedSegmentUris.contains(segKey)) {
          _downloadedSegmentUris.add(segKey);

          if (_downloadedSegmentUris.length == 1 && mediaSegmentUris.length > 3) {
            final idx = mediaSegmentUris.indexOf(seg);
            if (idx < mediaSegmentUris.length - 2) {
              continue;
            }
          }

          final chunkBytes = await _fetchChunk(resolvedSeg);
          if (chunkBytes != null && _isRecording) {
            // Check if chunk is fMP4 (.m4s) and extract pure ADTS AAC frames
            final adtsBytes = _fmp4Extractor.extractAdtsFromM4s(chunkBytes);
            if (adtsBytes != null) {
              _fileSink?.add(adtsBytes);
            } else {
              _fileSink?.add(chunkBytes);
            }
          }
        }
      }
    } catch (_) {
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
    } catch (_) {}

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
