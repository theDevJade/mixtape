import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ── Player background style ───────────────────────────────────────────────────

enum PlayerBackgroundStyle { blur, gradient, solid }

// ── Settings model ───────────────────────────────────────────────────────────

class AppSettings {
  final Brightness brightness;
  final AppColorScheme colorScheme;
  final double playerBlurIntensity;
  final bool showAlbumColorInPlayer;
  final PlayerBackgroundStyle playerBackgroundStyle;
  final bool crossfadeEnabled;
  final int crossfadeDurationSeconds;
  final double volume;
  // Customization
  final String? backgroundImagePath;
  final double fontScale;
  final bool showLyricsByDefault;
  // Output / streaming
  final bool normalizeVolume;
  final StreamQuality streamQuality;
  // Discord Rich Presence
  final bool discordRpcEnabled;
  final String discordRpcClientId;
  // yt-dlp
  final bool ytdlpAcknowledged;
  // Local audio file caching
  final bool cacheAudioFiles;
  // Player UI customization
  final bool useArtworkOnPlayerButtons;
  final bool rearrangePlayerControls;
  final bool showYoutubeVideoInPlayer;

  const AppSettings({
    this.brightness = Brightness.dark,
    this.colorScheme = AppColorScheme.midnight,
    this.playerBlurIntensity = 40.0,
    this.showAlbumColorInPlayer = true,
    this.playerBackgroundStyle = PlayerBackgroundStyle.blur,
    this.crossfadeEnabled = false,
    this.crossfadeDurationSeconds = 3,
    this.volume = 1.0,
    this.backgroundImagePath,
    this.fontScale = 1.0,
    this.showLyricsByDefault = false,
    this.normalizeVolume = false,
    this.streamQuality = StreamQuality.high,
    this.discordRpcEnabled = false,
    this.discordRpcClientId = '',
    this.ytdlpAcknowledged = false,
    this.cacheAudioFiles = false,
    this.useArtworkOnPlayerButtons = false,
    this.rearrangePlayerControls = false,
    this.showYoutubeVideoInPlayer = false,
  });

  AppSettings copyWith({
    Brightness? brightness,
    AppColorScheme? colorScheme,
    double? playerBlurIntensity,
    bool? showAlbumColorInPlayer,
    PlayerBackgroundStyle? playerBackgroundStyle,
    bool? crossfadeEnabled,
    int? crossfadeDurationSeconds,
    double? volume,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    double? fontScale,
    bool? showLyricsByDefault,
    bool? normalizeVolume,
    StreamQuality? streamQuality,
    bool? discordRpcEnabled,
    String? discordRpcClientId,
    bool? ytdlpAcknowledged,
    bool? cacheAudioFiles,
    bool? useArtworkOnPlayerButtons,
    bool? rearrangePlayerControls,
    bool? showYoutubeVideoInPlayer,
  }) {
    return AppSettings(
      brightness: brightness ?? this.brightness,
      colorScheme: colorScheme ?? this.colorScheme,
      playerBlurIntensity: playerBlurIntensity ?? this.playerBlurIntensity,
      showAlbumColorInPlayer:
          showAlbumColorInPlayer ?? this.showAlbumColorInPlayer,
      playerBackgroundStyle:
          playerBackgroundStyle ?? this.playerBackgroundStyle,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDurationSeconds:
          crossfadeDurationSeconds ?? this.crossfadeDurationSeconds,
      volume: volume ?? this.volume,
      backgroundImagePath: clearBackgroundImage
          ? null
          : backgroundImagePath ?? this.backgroundImagePath,
      fontScale: fontScale ?? this.fontScale,
      showLyricsByDefault: showLyricsByDefault ?? this.showLyricsByDefault,
      normalizeVolume: normalizeVolume ?? this.normalizeVolume,
      streamQuality: streamQuality ?? this.streamQuality,
      discordRpcEnabled: discordRpcEnabled ?? this.discordRpcEnabled,
      discordRpcClientId: discordRpcClientId ?? this.discordRpcClientId,
      ytdlpAcknowledged: ytdlpAcknowledged ?? this.ytdlpAcknowledged,
      cacheAudioFiles: cacheAudioFiles ?? this.cacheAudioFiles,
      useArtworkOnPlayerButtons:
          useArtworkOnPlayerButtons ?? this.useArtworkOnPlayerButtons,
      rearrangePlayerControls:
          rearrangePlayerControls ?? this.rearrangePlayerControls,
      showYoutubeVideoInPlayer:
          showYoutubeVideoInPlayer ?? this.showYoutubeVideoInPlayer,
    );
  }
}

enum StreamQuality { low, medium, high }

// ── Provider ─────────────────────────────────────────────────────────────────

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _keyBrightness = 'brightness';
  static const _keyColorScheme = 'color_scheme';
  static const _keyBlur = 'player_blur';
  static const _keyAlbumColor = 'album_color_in_player';
  static const _keyPlayerBgStyle = 'player_bg_style';
  static const _keyCrossfade = 'crossfade_enabled';
  static const _keyCrossfadeDuration = 'crossfade_duration';
  static const _keyVolume = 'volume';
  static const _keyBgImage = 'background_image_path';
  static const _keyFontScale = 'font_scale';
  static const _keyShowLyricsByDefault = 'show_lyrics_default';
  static const _keyNormalizeVolume = 'normalize_volume';
  static const _keyStreamQuality = 'stream_quality';
  static const _keyDiscordEnabled = 'discord_rpc_enabled';
  static const _keyDiscordClientId = 'discord_rpc_client_id';
  static const _keyYtdlpAck = 'ytdlp_acknowledged';
  static const keyCacheAudioFiles = 'cache_audio_files';
  static const _keyArtworkButtons = 'use_artwork_on_player_buttons';
  static const _keyRearrangeControls = 'rearrange_player_controls';
  static const _keyShowYoutubeVideoInPlayer = 'show_youtube_video_in_player';

  late SharedPreferences _prefs;

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final brightnessStr = _prefs.getString(_keyBrightness) ?? 'dark';
    final schemeStr = _prefs.getString(_keyColorScheme) ?? 'midnight';
    final bgStyle = _prefs.getString(_keyPlayerBgStyle) ?? 'blur';
    final qualityStr = _prefs.getString(_keyStreamQuality) ?? 'high';

    state = AppSettings(
      brightness: brightnessStr == 'light' ? Brightness.light : Brightness.dark,
      colorScheme: AppColorScheme.values.firstWhere(
        (e) => e.name == schemeStr,
        orElse: () => AppColorScheme.midnight,
      ),
      playerBlurIntensity: _prefs.getDouble(_keyBlur) ?? 40.0,
      showAlbumColorInPlayer: _prefs.getBool(_keyAlbumColor) ?? true,
      playerBackgroundStyle: PlayerBackgroundStyle.values.firstWhere(
        (e) => e.name == bgStyle,
        orElse: () => PlayerBackgroundStyle.blur,
      ),
      crossfadeEnabled: _prefs.getBool(_keyCrossfade) ?? false,
      crossfadeDurationSeconds: _prefs.getInt(_keyCrossfadeDuration) ?? 3,
      volume: _prefs.getDouble(_keyVolume) ?? 1.0,
      backgroundImagePath: _prefs.getString(_keyBgImage),
      fontScale: _prefs.getDouble(_keyFontScale) ?? 1.0,
      showLyricsByDefault: _prefs.getBool(_keyShowLyricsByDefault) ?? false,
      normalizeVolume: _prefs.getBool(_keyNormalizeVolume) ?? false,
      streamQuality: StreamQuality.values.firstWhere(
        (e) => e.name == qualityStr,
        orElse: () => StreamQuality.high,
      ),
      discordRpcEnabled: _prefs.getBool(_keyDiscordEnabled) ?? false,
      discordRpcClientId: _prefs.getString(_keyDiscordClientId) ?? '',
      ytdlpAcknowledged: _prefs.getBool(_keyYtdlpAck) ?? false,
      cacheAudioFiles: _prefs.getBool(keyCacheAudioFiles) ?? false,
      useArtworkOnPlayerButtons: _prefs.getBool(_keyArtworkButtons) ?? false,
      rearrangePlayerControls: _prefs.getBool(_keyRearrangeControls) ?? false,
      showYoutubeVideoInPlayer:
          _prefs.getBool(_keyShowYoutubeVideoInPlayer) ?? false,
    );
  }

  Future<void> setBrightness(Brightness b) async {
    state = state.copyWith(brightness: b);
    await _prefs.setString(
      _keyBrightness,
      b == Brightness.light ? 'light' : 'dark',
    );
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    state = state.copyWith(colorScheme: scheme);
    await _prefs.setString(_keyColorScheme, scheme.name);
  }

  Future<void> setPlayerBlur(double blur) async {
    state = state.copyWith(playerBlurIntensity: blur);
    await _prefs.setDouble(_keyBlur, blur);
  }

  Future<void> setShowAlbumColor(bool value) async {
    state = state.copyWith(showAlbumColorInPlayer: value);
    await _prefs.setBool(_keyAlbumColor, value);
  }

  Future<void> setPlayerBackgroundStyle(PlayerBackgroundStyle style) async {
    state = state.copyWith(playerBackgroundStyle: style);
    await _prefs.setString(_keyPlayerBgStyle, style.name);
  }

  Future<void> setCrossfade(bool enabled) async {
    state = state.copyWith(crossfadeEnabled: enabled);
    await _prefs.setBool(_keyCrossfade, enabled);
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    state = state.copyWith(crossfadeDurationSeconds: seconds);
    await _prefs.setInt(_keyCrossfadeDuration, seconds);
  }

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: v);
    await _prefs.setDouble(_keyVolume, v);
  }

  Future<void> setBackgroundImage(String? path) async {
    if (path == null) {
      state = state.copyWith(clearBackgroundImage: true);
      await _prefs.remove(_keyBgImage);
    } else {
      state = state.copyWith(backgroundImagePath: path);
      await _prefs.setString(_keyBgImage, path);
    }
  }

  Future<void> setFontScale(double scale) async {
    state = state.copyWith(fontScale: scale);
    await _prefs.setDouble(_keyFontScale, scale);
  }

  Future<void> setShowLyricsByDefault(bool value) async {
    state = state.copyWith(showLyricsByDefault: value);
    await _prefs.setBool(_keyShowLyricsByDefault, value);
  }

  Future<void> setNormalizeVolume(bool value) async {
    state = state.copyWith(normalizeVolume: value);
    await _prefs.setBool(_keyNormalizeVolume, value);
  }

  Future<void> setStreamQuality(StreamQuality q) async {
    state = state.copyWith(streamQuality: q);
    await _prefs.setString(_keyStreamQuality, q.name);
  }

  Future<void> setDiscordRpcEnabled(bool enabled) async {
    state = state.copyWith(discordRpcEnabled: enabled);
    await _prefs.setBool(_keyDiscordEnabled, enabled);
  }

  Future<void> setDiscordRpcClientId(String id) async {
    state = state.copyWith(discordRpcClientId: id);
    await _prefs.setString(_keyDiscordClientId, id);
  }

  Future<void> setYtdlpAcknowledged(bool v) async {
    state = state.copyWith(ytdlpAcknowledged: v);
    await _prefs.setBool(_keyYtdlpAck, v);
  }

  Future<void> setCacheAudioFiles(bool v) async {
    state = state.copyWith(cacheAudioFiles: v);
    await _prefs.setBool(keyCacheAudioFiles, v);
  }

  Future<void> setUseArtworkOnPlayerButtons(bool v) async {
    state = state.copyWith(useArtworkOnPlayerButtons: v);
    await _prefs.setBool(_keyArtworkButtons, v);
  }

  Future<void> setRearrangePlayerControls(bool v) async {
    state = state.copyWith(rearrangePlayerControls: v);
    await _prefs.setBool(_keyRearrangeControls, v);
  }

  Future<void> setShowYoutubeVideoInPlayer(bool v) async {
    state = state.copyWith(showYoutubeVideoInPlayer: v);
    await _prefs.setBool(_keyShowYoutubeVideoInPlayer, v);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
