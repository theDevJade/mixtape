import 'dart:async';
import 'dart:developer' as developer;

import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Discord Rich Presence wrapper around `dart_discord_presence`.
///
/// Supported platforms: macOS, Windows, Linux.
/// On mobile platforms [isSupported] returns false and all calls are no-ops.
class DiscordRpcService {
  DiscordRPC? _rpc;
  StreamSubscription<DiscordReadyEvent>? _readySub;
  StreamSubscription<DiscordDisconnectedEvent>? _disconnectedSub;
  StreamSubscription<DiscordErrorEvent>? _errorSub;

  bool _connected = false;
  String? _clientId;

  bool get isSupported => DiscordRPC.isAvailable;
  bool get isConnected => _connected && (_rpc?.isConnected ?? false);

  void _log(String message) {
    assert(() {
      developer.log(message, name: 'DiscordRpcService');
      return true;
    }());
  }

  /// Connects to Discord RPC.
  /// Returns true on success. Safe to call even if Discord is not running.
  Future<bool> connect(String clientId) async {
    final normalizedClientId = clientId.trim();
    _log(
      'connect called; supported=$isSupported clientIdEmpty=${normalizedClientId.isEmpty}',
    );
    if (!isSupported || normalizedClientId.isEmpty) return false;

    if (_rpc != null && _clientId == normalizedClientId && isConnected) {
      _log('connect skipped; already connected with same clientId');
      return true;
    }

    if (_rpc != null && _clientId != normalizedClientId) {
      _log('connect switching clientId; disconnecting previous session');
      await disconnect();
    }

    _rpc ??= DiscordRPC();
    _wireRpcListeners(_rpc!);

    try {
      if (!(_rpc!.isInitialized)) {
        _log('initializing DiscordRPC');
        await _rpc!.initialize(normalizedClientId);
      }
      _clientId = normalizedClientId;
      _connected = _rpc!.isConnected;
      _log(
        'connect result; initialized=${_rpc!.isInitialized} connected=$_connected',
      );
      return _connected;
    } catch (e) {
      _log('connect failed: $e');
      await disconnect();
      return false;
    }
  }

  /// Updates the Discord presence for the currently playing track.
  Future<void> setActivity({
    required String details,
    required String state,
    int? startTimestamp,
    int? endTimestamp,
    String? largeImageKey,
    String? largeImageUrl,
    String? largeImageText,
    String? smallImageKey,
    String? smallImageText,
  }) async {
    final rpc = _rpc;
    if (rpc == null || !isConnected) {
      _log(
        'setActivity skipped; rpcNull=${rpc == null} isConnected=$isConnected',
      );
      return;
    }

    final presence = DiscordPresence(
      type: DiscordActivityType.listening,
      details: details,
      state: state,
      statusDisplayType: DiscordStatusDisplayType.details,
      timestamps: (startTimestamp == null && endTimestamp == null)
          ? null
          : DiscordTimestamps(start: startTimestamp, end: endTimestamp),
      largeAsset: _buildAsset(
        key: largeImageKey,
        url: largeImageUrl,
        text: largeImageText,
        fallbackKey: 'mixtape_logo',
        fallbackText: 'Mixtape',
      ),
      smallAsset: _buildAsset(key: smallImageKey, text: smallImageText),
    );

    try {
      await rpc.setPresence(presence);
      _connected = rpc.isConnected;
      _log(
        'setActivity sent; details="$details" state="$state" connected=$_connected',
      );
    } catch (e) {
      _log('setActivity failed: $e');
      _connected = false;
    }
  }

  DiscordAsset? _buildAsset({
    String? key,
    String? url,
    String? text,
    String? fallbackKey,
    String? fallbackText,
  }) {
    final normalizedKey = key?.trim();
    final normalizedUrl = url?.trim();
    final normalizedText = text?.trim();
    final normalizedFallbackKey = fallbackKey?.trim();

    if (normalizedKey != null && normalizedKey.isNotEmpty) {
      return DiscordAsset.fromKey(
        normalizedKey,
        text: normalizedText?.isNotEmpty == true
            ? normalizedText
            : fallbackText,
      );
    }

    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return DiscordAsset.fromUrl(
        normalizedUrl,
        text: normalizedText?.isNotEmpty == true
            ? normalizedText
            : fallbackText,
      );
    }

    if (normalizedFallbackKey != null && normalizedFallbackKey.isNotEmpty) {
      return DiscordAsset.fromKey(
        normalizedFallbackKey,
        text: normalizedText?.isNotEmpty == true
            ? normalizedText
            : fallbackText,
      );
    }

    return null;
  }

  /// Clears the presence (e.g. when paused / stopped).
  Future<void> clearActivity() async {
    final rpc = _rpc;
    if (rpc == null || !isConnected) {
      _log(
        'clearActivity skipped; rpcNull=${rpc == null} isConnected=$isConnected',
      );
      return;
    }
    try {
      await rpc.clearPresence();
      _connected = rpc.isConnected;
      _log('clearActivity sent; connected=$_connected');
    } catch (e) {
      _log('clearActivity failed: $e');
      _connected = false;
    }
  }

  Future<void> disconnect() async {
    _log('disconnect called');
    _connected = false;

    try {
      await _readySub?.cancel();
    } catch (_) {}
    try {
      await _disconnectedSub?.cancel();
    } catch (_) {}
    try {
      await _errorSub?.cancel();
    } catch (_) {}
    _readySub = null;
    _disconnectedSub = null;
    _errorSub = null;

    if (_rpc != null) {
      try {
        await _rpc!.dispose();
      } catch (e) {
        _log('disconnect dispose failed: $e');
      }
    }

    _rpc = null;
    _clientId = null;
    _log('disconnect complete');
  }

  void _wireRpcListeners(DiscordRPC rpc) {
    _readySub ??= rpc.onReady.listen((_) {
      _connected = true;
      _log('onReady received; connected=true');
    });
    _disconnectedSub ??= rpc.onDisconnected.listen((_) {
      _connected = false;
      _log('onDisconnected received; connected=false');
    });
    _errorSub ??= rpc.onError.listen(
      (event) {
        _connected = false;
        _log(
          'onError received; code=${event.errorCode} message=${event.message}',
        );
      },
      onError: (e) {
        _connected = false;
        _log('onError stream error (broken pipe / socket): $e');
      },
    );
  }
}

// ── Riverpod provider ────────────────────────────────────────────────────────

final discordRpcServiceProvider = Provider<DiscordRpcService>((_) {
  return DiscordRpcService();
});
