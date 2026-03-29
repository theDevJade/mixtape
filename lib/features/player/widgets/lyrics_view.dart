import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lyrics/lyrics_service.dart';

/// Displays synced (scrolling) or plain lyrics for the current track.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final _scrollCtrl = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  /// True while the user's finger is actively on the scroll view.
  bool _fingerDown = false;

  /// Set when the finger lifts; auto-scroll waits this long before resuming.
  DateTime? _scrollEndedAt;

  static const _resumeGrace = Duration(seconds: 3);

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _suppressAutoScroll {
    if (_fingerDown) return true;
    final ended = _scrollEndedAt;
    if (ended == null) return false;
    return DateTime.now().difference(ended) < _resumeGrace;
  }

  void _scrollToActive(int idx) {
    if (!_scrollCtrl.hasClients) return;
    if (_suppressAutoScroll) return;

    final key = _itemKeys[idx];
    final itemContext = key?.currentContext;
    if (itemContext == null) return;

    final itemBox = itemContext.findRenderObject() as RenderBox?;
    if (itemBox == null || !itemBox.attached) return;

    // Get the scroll view's own RenderBox so we can measure relative position.
    final scrollBox =
        _scrollCtrl.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (scrollBox == null) return;

    // Item's top-left relative to the scroll view's top-left.
    final itemTopInViewport = itemBox
        .localToGlobal(Offset.zero, ancestor: scrollBox)
        .dy;

    // We want the item's top to sit at 35% down the viewport.
    final viewportHeight = _scrollCtrl.position.viewportDimension;
    final targetScroll =
        (_scrollCtrl.offset + itemTopInViewport - viewportHeight * 0.35).clamp(
          0.0,
          _scrollCtrl.position.maxScrollExtent,
        );

    _scrollCtrl.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider);
    final activeIdx = ref.watch(currentLyricIndexProvider);

    ref.listen(currentLyricIndexProvider, (prev, next) {
      if (next >= 0) _scrollToActive(next);
    });

    return lyricsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white54)),
      error: (_, _) => const _LyricsPlaceholder(
        icon: Icons.error_outline_rounded,
        message: 'Could not load lyrics',
      ),
      data: (result) {
        if (result == null || !result.hasAny) {
          return const _LyricsPlaceholder(
            icon: Icons.lyrics_rounded,
            message: 'No lyrics available',
          );
        }

        if (result.hasSynced) {
          return _SyncedLyricsView(
            lines: result.syncedLines,
            activeIndex: activeIdx,
            scrollController: _scrollCtrl,
            itemKeys: _itemKeys,
            onScrollNotification: (n) {
              if (n is UserScrollNotification) {
                _fingerDown = true;
                _scrollEndedAt = null;
              } else if (n is ScrollEndNotification) {
                _fingerDown = false;
                _scrollEndedAt = DateTime.now();
                // After the grace period, snap back to the active line.
                Future.delayed(
                  _resumeGrace + const Duration(milliseconds: 50),
                  () {
                    if (mounted) {
                      _scrollToActive(ref.read(currentLyricIndexProvider));
                    }
                  },
                );
              }
              return false;
            },
          );
        }

        // Plain text fallback
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            result.plainText!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.8,
            ),
          ),
        );
      },
    );
  }
}

class _SyncedLyricsView extends StatelessWidget {
  final List<LyricLine> lines;
  final int activeIndex;
  final ScrollController scrollController;
  final Map<int, GlobalKey> itemKeys;
  final bool Function(ScrollNotification) onScrollNotification;

  const _SyncedLyricsView({
    required this.lines,
    required this.activeIndex,
    required this.scrollController,
    required this.itemKeys,
    required this.onScrollNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: const [0.0, 0.12, 0.82, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: NotificationListener<ScrollNotification>(
            onNotification: onScrollNotification,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(
                top: 80,
                bottom: 200,
                left: 28,
                right: 28,
              ),
              itemCount: lines.length,
              itemBuilder: (context, i) {
                itemKeys[i] ??= GlobalKey();
                return _LyricLineWidget(
                  key: itemKeys[i],
                  text: lines[i].text.isEmpty ? '♪' : lines[i].text,
                  state: i == activeIndex
                      ? _LineState.active
                      : i < activeIndex
                      ? _LineState.past
                      : _LineState.upcoming,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum _LineState { past, active, upcoming }

class _LyricLineWidget extends StatelessWidget {
  final String text;
  final _LineState state;

  const _LyricLineWidget({super.key, required this.text, required this.state});

  @override
  Widget build(BuildContext context) {
    final isActive = state == _LineState.active;
    final isPast = state == _LineState.past;

    final color = isActive
        ? Colors.white
        : isPast
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.55);

    final fontSize = isActive ? 28.0 : 22.0;
    final fontWeight = isActive ? FontWeight.w700 : FontWeight.w500;
    final bottomPad = isActive ? 20.0 : 14.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: 1.25,
          letterSpacing: isActive ? -0.3 : 0,
        ),
        child: Text(text, textAlign: TextAlign.left),
      ),
    );
  }
}

class _LyricsPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;
  const _LyricsPlaceholder({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
