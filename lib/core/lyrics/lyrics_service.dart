import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_service.dart';
import '../models/track.dart';

const _tag = 'Lyrics';

// ── Data models ──────────────────────────────────────────────────────────────

class LyricLine {
  final Duration timestamp;
  final String text;
  const LyricLine({required this.timestamp, required this.text});
}

class LyricsResult {
  /// Time-synced lines (empty if only plain lyrics are available)
  final List<LyricLine> syncedLines;

  /// Raw plain-text lyrics (fallback when no synced lyrics exist)
  final String? plainText;

  const LyricsResult({this.syncedLines = const [], this.plainText});

  bool get hasSynced => syncedLines.isNotEmpty;
  bool get hasAny => syncedLines.isNotEmpty || (plainText?.isNotEmpty ?? false);
}

// ── LRCLIB client ─────────────────────────────────────────────────────────────

/// Fetches lyrics from lrclib.net - completely free, no API key required.
class LyricsService {
  static final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://lrclib.net/api',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Lrclib-Client': 'Mixtape (github.com/mixtape-app/mixtape)'},
    ),
  );

  static Future<LyricsResult?> fetch(Track track) async {
    // Skip album when it's a generic streaming provider label (e.g. "YouTube"),
    // since LRCLIB won't have that as an album and it causes a 404 miss.
    final album = _isGenericProvider(track.album) ? null : track.album;

    // For YouTube / URL-sourced tracks the raw title often contains
    // "Artist - Song (Official Video)" and the artist field holds a channel
    // name like "EdSheeranVEVO" or "Taylor Swift - Topic".  Clean both before
    // hitting LRCLIB so we get a real match.
    final cleanTitle = _extractCleanTitle(track.title);
    final cleanArtist = _extractCleanArtist(track.artist, track.title);

    dev.log(
      'fetch → rawTitle="${track.title}" cleanTitle="$cleanTitle" '
      'rawArtist="${track.artist}" cleanArtist="$cleanArtist" '
      'album="${album ?? '(skipped)'}" duration=${track.duration?.inSeconds}s',
      name: _tag,
    );

    try {
      final params = <String, dynamic>{
        'track_name': cleanTitle,
        if (cleanArtist != null) 'artist_name': cleanArtist,
        if (album != null) 'album_name': album,
        if (track.duration != null) 'duration': track.duration!.inSeconds,
      };

      final resp = await _dio.get('/get', queryParameters: params);
      final data = resp.data as Map<String, dynamic>;

      final synced = data['syncedLyrics'] as String?;
      final plain = data['plainLyrics'] as String?;

      if (synced == null && plain == null) {
        dev.log('/get returned no lyrics content', name: _tag);
        return null;
      }

      dev.log(
        '/get hit — synced=${synced != null} plain=${plain != null}',
        name: _tag,
      );
      return LyricsResult(
        syncedLines: synced != null ? _parseLrc(synced) : [],
        plainText: plain,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        dev.log('/get 404 — falling back to /search', name: _tag);
        return _fetchViaSearch(cleanTitle, cleanArtist);
      }
      dev.log('fetch error: $e', name: _tag);
      rethrow;
    }
  }

  /// Returns true for generic streaming-platform names that aren't real album names.
  static bool _isGenericProvider(String? album) {
    if (album == null) return false;
    const generic = {'youtube', 'vimeo', 'soundcloud', 'url'};
    return generic.contains(album.toLowerCase());
  }

  /// Fallback: use the /search endpoint with a cleaned-up track name.
  /// Tries with artist first, then without if that yields nothing.
  static Future<LyricsResult?> _fetchViaSearch(
    String cleanTitle,
    String? cleanArtist,
  ) async {
    dev.log(
      '/search → cleanTitle="$cleanTitle" artist="$cleanArtist"',
      name: _tag,
    );

    // First attempt: with artist
    if (cleanArtist != null) {
      final result = await _searchOnce(cleanTitle, cleanArtist);
      if (result != null) return result;
      dev.log(
        '/search with artist found nothing — retrying without',
        name: _tag,
      );
    }

    // Second attempt: title only (no artist_name)
    return _searchOnce(cleanTitle, null);
  }

  static Future<LyricsResult?> _searchOnce(
    String trackName,
    String? artistName,
  ) async {
    try {
      final params = <String, dynamic>{
        'track_name': trackName,
        if (artistName != null) 'artist_name': artistName,
      };

      final resp = await _dio.get('/search', queryParameters: params);
      final items = resp.data as List?;
      if (items == null || items.isEmpty) {
        dev.log('/search returned no results (artist=$artistName)', name: _tag);
        return null;
      }

      final data = items.first as Map<String, dynamic>;
      final synced = data['syncedLyrics'] as String?;
      final plain = data['plainLyrics'] as String?;

      if (synced == null && plain == null) {
        dev.log('/search first result has no lyrics content', name: _tag);
        return null;
      }

      dev.log(
        '/search hit — title="${data['trackName']}" '
        'artist="${data['artistName']}" synced=${synced != null} plain=${plain != null}',
        name: _tag,
      );
      return LyricsResult(
        syncedLines: synced != null ? _parseLrc(synced) : [],
        plainText: plain,
      );
    } on DioException catch (e) {
      dev.log('/search error: $e', name: _tag);
      return null;
    }
  }

  /// Strips common YouTube title noise so LRCLIB can match the real song name.
  /// "Artist - Song Title (Official Video)" → "Song Title"
  /// "Song Title [Lyrics]" → "Song Title"
  static String _extractCleanTitle(String title) {
    var clean = title;

    // "Artist - Song Title ..." → take everything after the first " - "
    final dashIdx = clean.indexOf(' - ');
    if (dashIdx > 0) clean = clean.substring(dashIdx + 3);

    // Strip trailing parentheticals: "(Official Video)", "[4K]", "ft. X", etc.
    clean = clean
        .replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '')
        .replaceAll(RegExp(r'\s+ft\..*', caseSensitive: false), '')
        .trim();

    return clean.isEmpty ? title : clean;
  }

  /// Derives a clean artist name suitable for LRCLIB.
  ///
  /// YouTube oEmbed returns channel names like "EdSheeranVEVO", "Ed Sheeran - Topic",
  /// or "The Weeknd" (already fine). Strategy:
  ///   1. Strip known YouTube channel suffixes (VEVO, " - Topic", "Official", etc.)
  ///   2. If the raw title contains "Artist - Song", prefer the prefix as the artist.
  static String? _extractCleanArtist(String? rawArtist, String title) {
    // Try to pull artist from "Artist - Song" title pattern first —
    // this is more reliable than the channel name.
    final dashIdx = title.indexOf(' - ');
    if (dashIdx > 0) {
      final fromTitle = title.substring(0, dashIdx).trim();
      if (fromTitle.isNotEmpty) return fromTitle;
    }

    if (rawArtist == null || rawArtist.isEmpty) return null;

    var clean = rawArtist;

    // Strip " - Topic" suffix (YouTube auto-generated channels)
    clean = clean.replaceAll(
      RegExp(r'\s*-\s*Topic$', caseSensitive: false),
      '',
    );
    // Strip "VEVO" suffix
    clean = clean.replaceAll(RegExp(r'VEVO$', caseSensitive: false), '');
    // Strip "Official" suffix
    clean = clean.replaceAll(RegExp(r'\s*Official$', caseSensitive: false), '');
    clean = clean.trim();

    return clean.isEmpty ? rawArtist : clean;
  }

  /// Parses LRC-format lyrics into a time-indexed list of lines.
  /// LRC format: `[MM:SS.xx] lyric text`
  static List<LyricLine> _parseLrc(String lrc) {
    final pattern = RegExp(r'\[(\d{1,2}):(\d{2})\.(\d{2,3})\](.*)');
    final lines = <LyricLine>[];

    for (final raw in lrc.split('\n')) {
      for (final match in pattern.allMatches(raw)) {
        final mm = int.parse(match.group(1)!);
        final ss = int.parse(match.group(2)!);
        final fractionStr = match.group(3)!;
        // Normalise to milliseconds whether it's 2 (centiseconds) or 3 digits
        final ms = fractionStr.length == 2
            ? int.parse(fractionStr) * 10
            : int.parse(fractionStr);
        final text = match.group(4)!.trim();

        lines.add(
          LyricLine(
            timestamp: Duration(minutes: mm, seconds: ss, milliseconds: ms),
            text: text,
          ),
        );
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

/// Fetches lyrics for the currently playing track. Auto-disposes when track changes.
final lyricsProvider = FutureProvider.autoDispose<LyricsResult?>((ref) async {
  final track = ref.watch(currentTrackProvider);
  if (track == null) return null;
  return LyricsService.fetch(track);
});

/// The index of the lyric line that matches the current playback position.
final currentLyricIndexProvider = Provider.autoDispose<int>((ref) {
  final lyricsAsync = ref.watch(lyricsProvider);
  final positionAsync = ref.watch(positionDataProvider);
  final track = ref.watch(currentTrackProvider);

  final lines = lyricsAsync.valueOrNull?.syncedLines ?? [];
  if (lines.isEmpty) return -1;

  final posData = positionAsync.valueOrNull;
  final rawPosition = posData?.position ?? Duration.zero;
  final position = _correctPosition(track, rawPosition, posData?.totalDuration);

  // Find the last line whose timestamp is <= current position
  int idx = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].timestamp <= position) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
});

/// Scales the raw just_audio position for tracks where the container reports
/// a doubled duration (certain YouTube m4a streams). Mirrors the correction
/// applied in the player UI's _effectivePosition helper.
Duration _correctPosition(
  Track? track,
  Duration rawPosition,
  Duration? runtimeDuration,
) {
  if (track == null || runtimeDuration == null) return rawPosition;
  final metadataMs = track.duration?.inMilliseconds ?? 0;
  if (metadataMs <= 0) return rawPosition;
  final runtimeMs = runtimeDuration.inMilliseconds;
  if (runtimeMs <= 0) return rawPosition;
  if (rawPosition < const Duration(seconds: 4)) return rawPosition;
  final ratio = runtimeMs / metadataMs;
  if (ratio >= 1.8 || ratio <= (1 / 1.8)) {
    return Duration(milliseconds: (rawPosition.inMilliseconds / ratio).round());
  }
  return rawPosition;
}
