import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../source_plugin.dart';

class YtDlpPlugin extends MixtapeSourcePlugin {
  static const _ackKey = 'ack';
  bool _acknowledged = false;

  final Map<String, Map<String, String>> _headerCache = {};

  @override
  String get id => 'com.mixtape.ytdlp';

  @override
  String get name => 'yt-dlp';

  @override
  String? get iconUrl =>
      'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/.github/logo.png';

  @override
  String get description =>
      'Resolves stream URLs via yt-dlp (desktop only). '
      'Requires yt-dlp to be installed and on your PATH.';

  @override
  Set<PluginCapability> get capabilities => const {
    PluginCapability.streamResolve,
  };

  @override
  List<PluginConfigField> get configFields => const [
    PluginConfigField(
      key: 'ytdlp_path',
      label: 'yt-dlp binary path (optional)',
      hint: 'Leave empty to use PATH (e.g. /usr/local/bin/yt-dlp)',
    ),
  ];

  static const _candidatePaths = [
    '/opt/homebrew/bin/yt-dlp',
    '/usr/local/bin/yt-dlp',
    '/usr/bin/yt-dlp',
  ];

  static const _pythonCandidates = [
    '/opt/homebrew/bin/python3',
    '/usr/local/bin/python3',
    '/usr/bin/python3',
  ];

  String _ytdlpBin = 'yt-dlp';
  String? _pythonBin;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _acknowledged = (config[_ackKey] ?? '') == 'true';
    final custom = config['ytdlp_path'] ?? '';
    if (custom.isNotEmpty) {
      _ytdlpBin = custom;
    } else {
      _ytdlpBin = await _resolveAbsolutePath() ?? _ytdlpBin;
    }
    _pythonBin = await _resolvePython();
  }

  Future<String?> _resolveAbsolutePath() async {
    for (final path in _candidatePaths) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<String?> _resolvePython() async {
    for (final path in _pythonCandidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  @override
  Future<bool> isConfigured() async => _acknowledged && _isDesktop;

  bool get _isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  Future<ProcessResult> _runYtDlp(List<String> args) async {
    Future<ProcessResult> run(String bin, List<String> a) => Process.run(
      bin,
      a,
      runInShell: false,
    ).timeout(const Duration(seconds: 30));

    try {
      return await run(_ytdlpBin, args);
    } on ProcessException catch (e) {
      if (!e.message.contains('Operation not permitted')) rethrow;
    }

    final python = _pythonBin;
    if (python == null) {
      throw Exception(
        'yt-dlp could not run and no Python interpreter was found.\n'
        'Install Python or yt-dlp standalone.',
      );
    }

    final scriptPath = await File(_ytdlpBin).resolveSymbolicLinks();
    return run(python, [scriptPath, ...args]);
  }

  Future<String> _resolve(String uri) async {
    final formatSelector = _formatSelectorForPlatform();
    final ProcessResult result;
    try {
      result = await _runYtDlp([
        '--dump-json',
        '--format',
        formatSelector,
        '--no-playlist',
        uri,
      ]);
    } on TimeoutException {
      throw Exception(
        'yt-dlp timed out (30s). Check your network or update yt-dlp.',
      );
    } catch (e) {
      throw Exception(
        'yt-dlp could not run: $e\nInstall it with: pip install yt-dlp',
      );
    }

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw Exception(
        'yt-dlp failed${stderr.isNotEmpty ? ': $stderr' : ' (exit ${result.exitCode})'}',
      );
    }

    final json =
        jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
    final url = json['url'] as String? ?? '';
    if (!url.startsWith('http')) {
      throw Exception('yt-dlp returned an unexpected URL: $url');
    }

    final ext = json['ext']?.toString();
    final acodec = json['acodec']?.toString();
    final formatId = json['format_id']?.toString();
    final protocol = json['protocol']?.toString();
    stderr.writeln(
      '[YTDLP] selected format_id=$formatId ext=$ext acodec=$acodec '
      'protocol=$protocol selector=$formatSelector',
    );

    final rawHeaders = json['http_headers'] as Map<String, dynamic>? ?? {};
    _headerCache[uri] = rawHeaders.cast<String, String>();

    return url;
  }

  String _formatSelectorForPlatform() {
    if (Platform.isMacOS || Platform.isIOS) {
      return 'bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio[acodec*=aac]/bestaudio/best';
    }
    return 'bestaudio[ext=webm]/bestaudio/best';
  }

  @override
  Future<String> resolveStreamUrl(String uri) async {
    if (!_acknowledged || !_isDesktop) return uri;
    return _resolve(uri);
  }

  @override
  Future<Map<String, String>> resolveStreamHeaders(String uri) async {
    if (!_acknowledged || !_isDesktop) return const {};
    return _headerCache[uri] ?? const {};
  }

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async =>
      [];

  @override
  Future<List<SourceResult>> search(String query) async => [];

  Future<String?> downloadPreviewFile(String uri) async {
    if (!_acknowledged || !_isDesktop) return null;

    final videoId =
        _extractVideoId(uri) ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final previewDir = Directory(
      p.join(Directory.systemTemp.path, 'mixtape_yt_previews'),
    );
    if (!await previewDir.exists()) {
      await previewDir.create(recursive: true);
    }

    final outTemplate = p.join(previewDir.path, '${videoId}_preview.%(ext)s');
    final selector =
        'best[ext=mp4][height<=360]/best[height<=360]/best[ext=mp4]/best';

    final result = await _runYtDlp([
      '--no-playlist',
      '--quiet',
      '--no-warnings',
      '--format',
      selector,
      '--output',
      outTemplate,
      uri,
    ]);

    if (result.exitCode != 0) {
      return null;
    }

    final files =
        previewDir
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith('${videoId}_preview.'))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );

    if (files.isEmpty) return null;
    return files.first.path;
  }

  String? _extractVideoId(String url) {
    final patterns = [
      RegExp(r'[?&]v=([^&]+)'),
      RegExp(r'youtu\.be/([^?&/]+)'),
      RegExp(r'youtube\.com/embed/([^?&/]+)'),
      RegExp(r'youtube\.com/shorts/([^?&/]+)'),
      RegExp(r'youtube\.com/live/([^?&/]+)'),
    ];
    for (final ptn in patterns) {
      final m = ptn.firstMatch(url);
      if (m != null && m.groupCount >= 1) return m.group(1);
    }
    return null;
  }

  void acknowledge() {
    _acknowledged = true;
  }

  bool get isAcknowledged => _acknowledged;

  @override
  Future<void> dispose() async => _headerCache.clear();
}
