/// Shared YouTube duration mismatch detection & position scaling.
///
/// YouTube m4a streams sometimes report a container duration that is ~2x the
/// actual track length. This module centralises the ratio-check and scaling
/// so it doesn't have to be duplicated across the now-playing screen, the
/// mini player, the Discord RPC module, etc.
library;

import '../models/track.dart';

const _mismatchRatio = 1.8;

/// Returns `true` when [a] and [b] differ by more than [_mismatchRatio].
bool isDurationClearlyMismatched(Duration a, Duration b) {
  if (a <= Duration.zero || b <= Duration.zero) return false;
  final aMs = a.inMilliseconds;
  final bMs = b.inMilliseconds;
  if (aMs <= 0 || bMs <= 0) return false;
  final ratio = aMs / bMs;
  return ratio >= _mismatchRatio || ratio <= (1 / _mismatchRatio);
}

bool _isYouTubeUrl(String uriText) {
  final uri = Uri.tryParse(uriText);
  if (uri == null || !uri.hasScheme) return false;
  final host = uri.host.toLowerCase();
  return host.contains('youtube.com') || host.endsWith('youtu.be');
}

bool _isYouTubeTrack(Track track) {
  return track.sourcePluginId == 'com.mixtape.youtube' ||
      _isYouTubeUrl(track.uri);
}

/// The "true" duration for display purposes.
///
/// If the runtime duration reported by the player is wildly different from the
/// metadata duration and the track comes from YouTube, prefer the metadata
/// value because the container is lying.
Duration effectiveDuration(Track track, Duration runtimeDuration) {
  final metadataDuration = track.duration;
  if (metadataDuration == null || metadataDuration <= Duration.zero) {
    return runtimeDuration;
  }
  if (runtimeDuration <= Duration.zero) return metadataDuration;
  if (!_isYouTubeTrack(track)) return runtimeDuration;

  final runtimeMs = runtimeDuration.inMilliseconds;
  final metadataMs = metadataDuration.inMilliseconds;
  if (metadataMs <= 0) return runtimeDuration;

  final ratio = runtimeMs / metadataMs;
  if (ratio >= _mismatchRatio || ratio <= (1 / _mismatchRatio)) {
    return metadataDuration;
  }
  return runtimeDuration;
}

/// Scales the raw player position to the corrected timeline when the
/// container reports a doubled duration.
///
/// During the first 4 seconds of a new track (startup window) the raw
/// position is returned as-is to avoid jitter from cross-fade handoff.
Duration effectivePosition(
  Track track,
  Duration rawPosition,
  Duration runtimeDuration,
) {
  final metadataDuration = track.duration;
  if (metadataDuration == null || metadataDuration <= Duration.zero) {
    return rawPosition;
  }
  if (runtimeDuration <= Duration.zero) return rawPosition;
  if (rawPosition < const Duration(seconds: 4)) return rawPosition;
  if (!_isYouTubeTrack(track)) return rawPosition;

  final runtimeMs = runtimeDuration.inMilliseconds;
  final metadataMs = metadataDuration.inMilliseconds;
  if (metadataMs <= 0) return rawPosition;

  final ratio = runtimeMs / metadataMs;
  if (ratio >= _mismatchRatio || ratio <= (1 / _mismatchRatio)) {
    return Duration(milliseconds: (rawPosition.inMilliseconds / ratio).round());
  }
  return rawPosition;
}

/// Converts a target seek position (in the corrected timeline) back to the
/// raw player timeline, if duration scaling is active.
Duration rawSeekPosition(
  Track track,
  Duration targetPosition,
  Duration runtimeDuration,
) {
  final metadataDuration = track.duration;
  if (metadataDuration == null || metadataDuration <= Duration.zero) {
    return targetPosition;
  }
  if (runtimeDuration <= Duration.zero) return targetPosition;
  if (!_isYouTubeTrack(track)) return targetPosition;

  final runtimeMs = runtimeDuration.inMilliseconds;
  final metadataMs = metadataDuration.inMilliseconds;
  if (metadataMs <= 0) return targetPosition;

  final ratio = runtimeMs / metadataMs;
  if (ratio >= _mismatchRatio || ratio <= (1 / _mismatchRatio)) {
    final rawMs = (targetPosition.inMilliseconds * ratio).round();
    return Duration(milliseconds: rawMs.clamp(0, runtimeMs));
  }
  return targetPosition;
}
