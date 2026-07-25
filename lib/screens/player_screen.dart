import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';

// TV D-pad seek amount
const _kSeekSecs = 10;

class PlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;
  final String? epgTitle;
  final List<Channel>? channels;
  final int? channelIndex;
  final XtreamService? service;
  final bool isLive;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.epgTitle,
    this.channels,
    this.channelIndex,
    this.service,
    this.isLive = false,
  });

  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  bool _showControls = true;
  Timer? _hideTimer;

  // Current channel state
  late String _title;
  late String _streamUrl;
  String? _epgTitle;
  late int _chanIdx;
  bool _hasError = false;

  // Zapping banner
  bool _showBanner = false;
  Timer? _bannerTimer;
  Channel? _bannerChannel;

  // Track state
  Tracks _tracks = const Tracks();
  Track _currentTrack = const Track();

  bool get _canZap =>
      widget.channels != null &&
      widget.channels!.isNotEmpty &&
      widget.service != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _title     = widget.title;
    _streamUrl = widget.streamUrl;
    _epgTitle  = widget.epgTitle;
    _chanIdx   = widget.channelIndex ?? 0;

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _player     = Player();
    _controller = VideoController(_player);

    // Listen to track changes
    _player.stream.tracks.listen((t) {
      if (mounted) setState(() => _tracks = t);
    });
    _player.stream.track.listen((t) {
      if (mounted) setState(() => _currentTrack = t);
    });
    _player.stream.error.listen((e) {
      if (e.isNotEmpty && mounted) setState(() => _hasError = true);
    });

    _loadStream(_streamUrl);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _bannerTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  // ── Stream loading ─────────────────────────────────────────────────────────

  Future<void> _loadStream(String url) async {
    if (mounted) setState(() => _hasError = false);
    await _player.open(Media(url, httpHeaders: {
      'User-Agent': 'Mozilla/5.0',
      'Connection': 'keep-alive',
    }));
  }

  // ── Zapping ────────────────────────────────────────────────────────────────

  void _switchChannel(int delta) {
    if (!_canZap) return;
    final channels = widget.channels!;
    final newIdx = (_chanIdx + delta).clamp(0, channels.length - 1);
    if (newIdx == _chanIdx) return;

    final ch = channels[newIdx];
    setState(() {
      _chanIdx       = newIdx;
      _title         = ch.name;
      _streamUrl     = widget.service!.liveStreamUrl(ch.id);
      _epgTitle      = null;
      _hasError      = false;
      _showBanner    = true;
      _bannerChannel = ch;
    });

    _loadStream(_streamUrl);

    // Fetch EPG for new channel
    widget.service!.getShortEpg(ch.id).then((epg) {
      if (!mounted || epg.isEmpty) return;
      final now = DateTime.now();
      try {
        final cur = epg.firstWhere(
          (e) => e.start.isBefore(now) && e.end.isAfter(now),
          orElse: () => epg.first,
        );
        if (mounted) setState(() => _epgTitle = cur.title);
      } catch (_) {}
    });

    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  // ── Controls visibility ────────────────────────────────────────────────────

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTapScreen() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  // ── Track selector ─────────────────────────────────────────────────────────

  void _showTrackSelector() {
    _hideTimer?.cancel(); // don't hide while sheet is open
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TrackSelectorSheet(
        player: _player,
        tracks: _tracks,
        currentTrack: _currentTrack,
      ),
    ).whenComplete(_startHideTimer);
  }

  // ── D-pad / keyboard ───────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Zapping: up/down
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.channelUp) {
      _switchChannel(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.channelDown) {
      _switchChannel(1);
      return KeyEventResult.handled;
    }
    // Seek / play-pause (only for VOD)
    final dur = _player.state.duration;
    if (dur == Duration.zero) return KeyEventResult.ignored;

    final pos = _player.state.position;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.mediaFastForward) {
      final next = pos + const Duration(seconds: _kSeekSecs);
      _player.seek(next < dur ? next : dur);
      _onTapScreen();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.mediaRewind) {
      final prev = pos - const Duration(seconds: _kSeekSecs);
      _player.seek(prev > Duration.zero ? prev : Duration.zero);
      _onTapScreen();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _player.playOrPause();
      _onTapScreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _onKey,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapScreen,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [

          // ── Video ──────────────────────────────────────────────────────────
          Video(controller: _controller, controls: NoVideoControls),

          // ── Buffering indicator ────────────────────────────────────────────
          StreamBuilder<bool>(
            stream: _player.stream.buffering,
            builder: (_, snap) => (snap.data ?? false)
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.celeste, strokeWidth: 3))
              : const SizedBox.shrink(),
          ),

          // ── Error overlay ──────────────────────────────────────────────────
          if (_hasError)
            _ErrorOverlay(onRetry: () {
              setState(() => _hasError = false);
              _loadStream(_streamUrl);
            }),

          // ── Top bar (auto-hides) ───────────────────────────────────────────
          if (!_hasError)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              top: _showControls ? 0 : -120,
              left: 0, right: 0,
              child: _TopBar(
                title: _title,
                epgTitle: _epgTitle,
                onBack: () => Navigator.pop(context),
                onSettings: _showTrackSelector,
                hasAudioTracks: _tracks.audio.length > 1,
                hasSubtitleTracks: _tracks.subtitle.length > 1,
              ),
            ),

          // ── Bottom controls (auto-hides) ───────────────────────────────────
          if (!_hasError)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _showControls ? 0 : -120,
              left: 0, right: 0,
              child: _BottomControls(player: _player, isLive: widget.isLive),
            ),

          // ── Zapping banner ─────────────────────────────────────────────────
          if (_canZap && _showBanner && _bannerChannel != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _ChannelBanner(
                channel: _bannerChannel!,
                epgTitle: _epgTitle,
                index: _chanIdx + 1,
                total: widget.channels!.length,
              ),
            ),
        ]),
      ),
    ),
  );
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final String? epgTitle;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final bool hasAudioTracks;
  final bool hasSubtitleTracks;

  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onSettings,
    this.epgTitle,
    this.hasAudioTracks = false,
    this.hasSubtitleTracks = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xDD000000), Colors.transparent])),
    padding: const EdgeInsets.fromLTRB(4, 8, 8, 28),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Back button
      IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBack),

      // Title + EPG
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (epgTitle != null && epgTitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.tv, color: AppColors.celeste, size: 12),
              const SizedBox(width: 4),
              Expanded(child: Text(epgTitle!,
                style: const TextStyle(color: AppColors.celeste, fontSize: 12,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      )),

      // ⚙️ Settings gear — always visible, shows dot badge if tracks available
      Stack(children: [
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
          tooltip: 'Audio y Subtítulos',
          onPressed: onSettings),
        if (hasAudioTracks || hasSubtitleTracks)
          Positioned(
            top: 10, right: 10,
            child: Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                color: AppColors.celeste, shape: BoxShape.circle),
            ),
          ),
      ]),
    ]),
  );
}

// ─── Bottom controls ──────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final Player player;
  final bool isLive;
  const _BottomControls({required this.player, this.isLive = false});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.bottomCenter, end: Alignment.topCenter,
      colors: [Color(0xDD000000), Colors.transparent])),
    padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
    child: StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (_, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (_, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            final isLive = this.isLive;
            return StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (_, playSnap) {
                final playing = playSnap.data ?? false;
                return Row(children: [
                  // Play / Pause
                  GestureDetector(
                    onTap: () => player.playOrPause(),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 30)),
                  const SizedBox(width: 12),

                  if (isLive) ...[
                    // LIVE badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.withOpacity(0.6))),
                      child: const Text('● EN VIVO',
                        style: TextStyle(color: Colors.red, fontSize: 10,
                          fontWeight: FontWeight.bold))),
                    const Spacer(),
                  ] else ...[
                    // Position time
                    Text(_fmt(pos),
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 8),
                    // Seek slider
                    Expanded(child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: AppColors.celeste,
                        thumbColor: AppColors.celeste,
                        inactiveTrackColor: Colors.white24,
                        overlayColor: AppColors.celeste.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: dur.inMilliseconds > 0
                            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                            : 0,
                        min: 0, max: 1,
                        onChanged: (v) => player.seek(
                            Duration(milliseconds: (v * dur.inMilliseconds).round())),
                      ),
                    )),
                    const SizedBox(width: 8),
                    // Duration
                    Text(_fmt(dur),
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ]);
              },
            );
          },
        );
      },
    ),
  );

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ─── Track selector sheet ─────────────────────────────────────────────────────
class _TrackSelectorSheet extends StatefulWidget {
  final Player player;
  final Tracks tracks;
  final Track currentTrack;

  const _TrackSelectorSheet({
    required this.player,
    required this.tracks,
    required this.currentTrack,
  });

  @override
  State<_TrackSelectorSheet> createState() => _TrackSelectorSheetState();
}

class _TrackSelectorSheetState extends State<_TrackSelectorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  bool get _hasAudio    => widget.tracks.audio.length > 1;
  bool get _hasSubtitle => widget.tracks.subtitle.length > 1;

  @override
  void initState() {
    super.initState();
    final count = (_hasAudio ? 1 : 0) + (_hasSubtitle ? 1 : 0);
    _tab = TabController(length: count == 0 ? 1 : count, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tabs    = <Tab>[];
    final views   = <Widget>[];

    if (_hasAudio) {
      tabs.add(const Tab(icon: Icon(Icons.headphones_rounded, size: 18), text: 'Audio'));
      views.add(_AudioTrackList(player: widget.player, tracks: widget.tracks.audio,
          current: widget.currentTrack.audio));
    }
    if (_hasSubtitle) {
      tabs.add(const Tab(icon: Icon(Icons.subtitles_rounded, size: 18), text: 'Subtítulos'));
      views.add(_SubtitleTrackList(player: widget.player, tracks: widget.tracks.subtitle,
          current: widget.currentTrack.subtitle));
    }

    // If nothing available
    if (tabs.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1020),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 40),
          const SizedBox(height: 16),
          const Text('No hay pistas adicionales disponibles',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Este stream no incluye pistas de audio o subtítulos alternativas.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
        ]),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2))),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(children: [
            const Icon(Icons.settings_rounded, color: AppColors.celeste, size: 18),
            const SizedBox(width: 8),
            const Text('Audio y Subtítulos',
              style: TextStyle(color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.bold)),
          ]),
        ),
        // Tabs (only if both sections available)
        if (tabs.length > 1)
          TabBar(
            controller: _tab,
            tabs: tabs,
            indicatorColor: AppColors.celeste,
            labelColor: AppColors.celeste,
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.label,
          ),
        // Content
        Flexible(child: tabs.length > 1
          ? TabBarView(controller: _tab, children: views)
          : views.first),
      ]),
    );
  }
}

// ── Audio track list ──────────────────────────────────────────────────────────
class _AudioTrackList extends StatefulWidget {
  final Player player;
  final List<AudioTrack> tracks;
  final AudioTrack current;
  const _AudioTrackList({required this.player, required this.tracks, required this.current});
  @override State<_AudioTrackList> createState() => _AudioTrackListState();
}
class _AudioTrackListState extends State<_AudioTrackList> {
  late AudioTrack _selected;
  @override void initState() { super.initState(); _selected = widget.current; }

  @override
  Widget build(BuildContext context) => ListView.builder(
    shrinkWrap: true,
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: widget.tracks.length,
    itemBuilder: (_, i) {
      final t = widget.tracks[i];
      final label = _trackLabel(t.title, t.language, i);
      final isSelected = t.id == _selected.id;
      return ListTile(
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? AppColors.celeste : Colors.white38, size: 20),
        title: Text(label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14)),
        subtitle: (t.language != null && t.language!.isNotEmpty &&
                   t.title != null && t.language != t.title)
          ? Text(t.language!,
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
        onTap: () {
          widget.player.setAudioTrack(t);
          setState(() => _selected = t);
        },
      );
    },
  );

  String _trackLabel(String? title, String? lang, int idx) {
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return lang.toUpperCase();
    return 'Pista ${idx + 1}';
  }
}

// ── Subtitle track list ───────────────────────────────────────────────────────
class _SubtitleTrackList extends StatefulWidget {
  final Player player;
  final List<SubtitleTrack> tracks;
  final SubtitleTrack current;
  const _SubtitleTrackList({required this.player, required this.tracks, required this.current});
  @override State<_SubtitleTrackList> createState() => _SubtitleTrackListState();
}
class _SubtitleTrackListState extends State<_SubtitleTrackList> {
  late SubtitleTrack _selected;
  @override void initState() { super.initState(); _selected = widget.current; }

  @override
  Widget build(BuildContext context) {
    // Prepend "Sin subtítulos" option
    final noSub = SubtitleTrack.no();
    final allTracks = [noSub, ...widget.tracks.where((t) => t.id != noSub.id)];

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: allTracks.length,
      itemBuilder: (_, i) {
        final t = allTracks[i];
        final isNone = t.id == noSub.id;
        final label = isNone ? 'Sin subtítulos' : _trackLabel(t.title, t.language, i - 1);
        final isSelected = t.id == _selected.id;
        return ListTile(
          leading: Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? AppColors.celeste : Colors.white38, size: 20),
          title: Text(label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14)),
          subtitle: (!isNone && t.language != null && t.language!.isNotEmpty &&
                     t.title != null && t.language != t.title)
            ? Text(t.language!,
                style: const TextStyle(color: Colors.white38, fontSize: 12))
            : null,
          onTap: () {
            widget.player.setSubtitleTrack(t);
            setState(() => _selected = t);
          },
        );
      },
    );
  }

  String _trackLabel(String? title, String? lang, int idx) {
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return lang.toUpperCase();
    return 'Subtítulo ${idx + 1}';
  }
}

// ─── Error overlay ────────────────────────────────────────────────────────────
class _ErrorOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorOverlay({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 60),
      const SizedBox(height: 16),
      const Text('No se pudo reproducir el stream',
        style: TextStyle(color: Colors.white, fontSize: 16)),
      const SizedBox(height: 8),
      const Text('Verifica tu conexión o intenta con otro canal',
        style: TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.celeste)),
    ]),
  );
}

// ─── Channel banner (zapping) ─────────────────────────────────────────────────
class _ChannelBanner extends StatelessWidget {
  final Channel channel;
  final String? epgTitle;
  final int index;
  final int total;

  const _ChannelBanner({
    required this.channel, required this.epgTitle,
    required this.index, required this.total,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.bottomCenter, end: Alignment.topCenter,
      colors: [Color(0xEE000000), Colors.transparent])),
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      // Logo
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: channel.streamIcon.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: channel.streamIcon,
              width: 60, height: 45, fit: BoxFit.contain,
              errorWidget: (_, __, ___) => _iconBox())
          : _iconBox(),
      ),
      const SizedBox(width: 16),
      // Info
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('$index/$total',
              style: const TextStyle(color: AppColors.celeste, fontSize: 12,
                fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withOpacity(0.6))),
              child: const Text('● EN VIVO',
                style: TextStyle(color: Colors.red, fontSize: 9,
                  fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 4),
          Text(channel.name,
            style: const TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black87, blurRadius: 6)]),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (epgTitle != null && epgTitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.tv, color: AppColors.celeste, size: 13),
              const SizedBox(width: 5),
              Expanded(child: Text(epgTitle!,
                style: const TextStyle(color: AppColors.celeste, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ] else
            const Text('Cargando programa...',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      )),
    ]),
  );

  Widget _iconBox() => Container(
    width: 60, height: 45,
    decoration: BoxDecoration(
      color: const Color(0xFF0D1020),
      borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.tv, color: AppColors.celeste, size: 24));
}
