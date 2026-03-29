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

/// Returns the raw player position, clamped to the effective duration so
/// the slider never overshoots.
///
/// Previous versions tried to *scale* the position when a YouTube container
/// reported a doubled duration.  In practice the audio plays at 1x and
/// just_audio's position is already correct — only the container's
/// *duration* is wrong.  Scaling caused the slider to sit at ~50 % when the
/// stream naturally ended, making it look like the song finished early.
Duration effectivePosition(
  Track track,
  Duration rawPosition,
  Duration runtimeDuration,
) {
  final eff = effectiveDuration(track, runtimeDuration);
  if (rawPosition > eff && eff > Duration.zero) return eff;
  return rawPosition;
}

/// Converts a target seek position back to the raw player timeline.
///
/// Because we no longer scale position, this is just a clamp to the
/// player's actual duration so we never seek past the stream end.
Duration rawSeekPosition(
  Track track,
  Duration targetPosition,
  Duration runtimeDuration,
) {
  if (runtimeDuration > Duration.zero && targetPosition > runtimeDuration) {
    return runtimeDuration;
  }
  return targetPosition;
}
