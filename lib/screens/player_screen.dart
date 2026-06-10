import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../models/epg_entry.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';

// TV D-pad seek amount
const _kSeekSecs = 10;

class PlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;
  /// Programa EPG actual (solo para TV en vivo)
  final String? epgTitle;
  /// Lista completa de canales para zapping (solo TV en vivo)
  final List<Channel>? channels;
  final int? channelIndex;
  final XtreamService? service;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.epgTitle,
    this.channels,
    this.channelIndex,
    this.service,
  });

  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  bool _showBar = true;
  Timer? _hideTimer;

  // Estado mutable del canal actual
  late String _title;
  late String _streamUrl;
  String? _epgTitle;
  late int _chanIdx;

  // Banner de cambio de canal
  bool _showBanner = false;
  Timer? _bannerTimer;
  Channel? _bannerChannel; // canal que se muestra en el banner

  bool get _canZap =>
    widget.channels != null &&
    widget.channels!.isNotEmpty &&
    widget.service != null;

  @override
  void initState() {
    super.initState();
    _title      = widget.title;
    _streamUrl  = widget.streamUrl;
    _epgTitle   = widget.epgTitle;
    _chanIdx    = widget.channelIndex ?? 0;
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(_streamUrl),
      httpHeaders: {'User-Agent': 'Mozilla/5.0', 'Connection': 'keep-alive'},
    );
    try {
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        allowedScreenSleep: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.celeste,
          handleColor: AppColors.gradStart,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
      );
      if (mounted) setState(() {});
      _startHideTimer();
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  // ── Cambio de canal (zapping) ─────────────────────────────────────────────
  void _switchChannel(int delta) {
    if (!_canZap) return;
    final channels = widget.channels!;
    final newIdx = (_chanIdx + delta).clamp(0, channels.length - 1);
    if (newIdx == _chanIdx) return;

    final ch = channels[newIdx];
    setState(() {
      _chanIdx     = newIdx;
      _title       = ch.name;
      _streamUrl   = widget.service!.liveStreamUrl(ch.id);
      _epgTitle    = null;
      _hasError    = false;
      _showBanner  = true;
      _bannerChannel = ch;
    });

    // Reinicializar reproductor
    _hideTimer?.cancel();
    _chewieController?.dispose();
    _chewieController = null;
    _videoController.dispose();
    _initPlayer();

    // Buscar EPG del nuevo canal
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

    // Auto-ocultar banner tras 3 s
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBar = false);
    });
  }

  void _onTapScreen() {
    setState(() => _showBar = true);
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
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  // D-pad / keyboard handling
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // ── Zapping: arriba / abajo ──────────────────────────────────────────
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

    // ── Seek: izquierda / derecha ────────────────────────────────────────
    if (_videoController.value.duration == Duration.zero) {
      return KeyEventResult.ignored;
    }
    final pos = _videoController.value.position;
    final dur = _videoController.value.duration;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.mediaFastForward) {
      final next = pos + const Duration(seconds: _kSeekSecs);
      _videoController.seekTo(next < dur ? next : dur);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.mediaRewind) {
      final prev = pos - const Duration(seconds: _kSeekSecs);
      _videoController.seekTo(prev > Duration.zero ? prev : Duration.zero);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _videoController.value.isPlaying
          ? _videoController.pause()
          : _videoController.play();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _onKey,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Reproductor ──────────────────────────────────────────────────
        if (_hasError)
          _buildError()
        else if (_chewieController == null)
          const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.celeste),
            SizedBox(height: 16),
            Text('Cargando stream...', style: TextStyle(color: Colors.white54)),
          ]))
        else
          Stack(children: [
            Chewie(controller: _chewieController!),
            // GestureDetector solo en parte superior para no tapar seek bar
            Positioned(
              top: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.7,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onTapScreen,
                child: const SizedBox.expand(),
              ),
            ),
          ]),

        // ── Barra superior auto-ocultable ────────────────────────────────
        if (!_hasError)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _showBar ? 0 : -100,
            left: 0, right: 0,
            child: _TopBar(
              title: _title,
              epgTitle: _epgTitle,
              onBack: () => Navigator.pop(context),
            ),
          ),

        // ── Banner de zapping (esquina inferior izquierda, estilo TV) ────
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
  );

  Widget _buildError() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, color: Colors.red, size: 60),
    const SizedBox(height: 16),
    const Text('No se pudo reproducir el stream',
      style: TextStyle(color: Colors.white, fontSize: 16)),
    const SizedBox(height: 8),
    const Text('Verifica tu conexión o intenta con otro canal',
      style: TextStyle(color: Colors.white54, fontSize: 13)),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      onPressed: () { setState(() => _hasError = false); _initPlayer(); },
      icon: const Icon(Icons.refresh), label: const Text('Reintentar'),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.celeste)),
  ]));
}

// ─── Banner de cambio de canal (estilo TV) ────────────────────────────────────
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
    decoration: const BoxDecoration(
      gradient: LinearGradient(
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

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final String? epgTitle;
  final VoidCallback onBack;
  // Engrane desactivado: video_player no expone track selection
  // Reactivar cuando se migre a media_kit
  const _TopBar({required this.title, required this.onBack, this.epgTitle});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xDD000000), Colors.transparent])),
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 28),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBack),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
            style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (epgTitle != null && epgTitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.tv, color: AppColors.celeste, size: 12),
              const SizedBox(width: 4),
              Expanded(child: Text(epgTitle!, style: const TextStyle(
                color: AppColors.celeste, fontSize: 12,
                fontWeight: FontWeight.w400,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      )),
      // Engrane quitado: video_player no expone track selection
      // if (onSettings != null)
      //   IconButton(icon: Icon(Icons.settings...), onPressed: onSettings),
    ]),
  );
}
