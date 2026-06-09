import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String streamUrl;
  const PlayerScreen({super.key, required this.title, required this.streamUrl});
  @override State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  // Auto-ocultar barra
  bool _showBar = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
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
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.celeste,
          handleColor: AppColors.gradStart,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
      );
      setState(() {});
      // Ocultar barra automáticamente al iniciar
      _startHideTimer();
    } catch (e) {
      setState(() => _hasError = true);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBar = false);
    });
  }

  void _onTapScreen() {
    if (_showBar) {
      // Si ya se ve la barra, reiniciar el timer
      _startHideTimer();
    } else {
      // Si estaba oculta, mostrarla y arrancar timer
      setState(() => _showBar = true);
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _openSettings() {
    _hideTimer?.cancel();
    setState(() => _showBar = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(videoController: _videoController),
    ).then((_) => _startHideTimer());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      onTap: _onTapScreen,
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        // ── Reproductor ──────────────────────────────────────────────
        if (_hasError)
          _buildError()
        else if (_chewieController == null)
          const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.celeste),
            SizedBox(height: 16),
            Text('Cargando stream...', style: TextStyle(color: Colors.white54)),
          ]))
        else
          Chewie(controller: _chewieController!),

        // ── Barra superior auto-ocultable ────────────────────────────
        if (!_hasError)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _showBar ? 0 : -80,
            left: 0, right: 0,
            child: _TopBar(
              title: widget.title,
              onBack: () => Navigator.pop(context),
              onSettings: _chewieController != null ? _openSettings : null,
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

// ─── Barra superior translúcida ───────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSettings;
  const _TopBar({required this.title, required this.onBack, this.onSettings});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xCC000000), Colors.transparent])),
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
    child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
      Expanded(child: Text(title,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
        maxLines: 1, overflow: TextOverflow.ellipsis)),
      if (onSettings != null)
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
          tooltip: 'Audio y subtítulos',
          onPressed: onSettings),
    ]),
  );
}

// ─── Panel de audio y subtítulos ──────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final VideoPlayerController videoController;
  const _SettingsSheet({required this.videoController});
  @override State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  List<_TrackInfo> _audioTracks = [];
  List<_TrackInfo> _subTracks = [];
  int _selAudio = 0;
  int _selSub = -1;

  @override void initState() { super.initState(); _loadTracks(); }

  void _loadTracks() {
    try {
      final dynamic value = widget.videoController.value;
      final dynamic rawTracks = value.tracks;
      if (rawTracks is List) {
        final audio = <_TrackInfo>[];
        final subs  = <_TrackInfo>[];
        for (int i = 0; i < rawTracks.length; i++) {
          try {
            final t = rawTracks[i];
            final String type  = t.trackType.toString();
            final String label = (t.label ?? '').toString();
            final String lang  = (t.language ?? '').toString();
            if (type.contains('audio')) {
              audio.add(_TrackInfo(i, label.isNotEmpty ? label : 'Pista ${audio.length + 1}', lang));
            } else if (type.contains('text')) {
              subs.add(_TrackInfo(i, label.isNotEmpty ? label : 'Subtítulo ${subs.length + 1}', lang));
            }
          } catch (_) {}
        }
        if (mounted) setState(() { _audioTracks = audio; _subTracks = subs; });
      }
    } catch (_) {}
  }

  void _selectAudio(int i) {
    try { (widget.videoController as dynamic).setTrackParameters('audio', i); } catch (_) {}
    setState(() => _selAudio = i);
  }
  void _selectSub(int i) {
    try { (widget.videoController as dynamic).setTrackParameters('text', i); } catch (_) {}
    setState(() => _selSub = i);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _audioTracks.isNotEmpty || _subTracks.isNotEmpty;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0D1020),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 10, bottom: 2),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            Icon(Icons.settings, color: AppColors.celeste, size: 20),
            SizedBox(width: 10),
            Text('Audio y subtítulos',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ])),
        const Divider(color: Colors.white10, height: 1),
        if (!hasContent)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            child: Column(children: [
              Icon(Icons.info_outline, color: Colors.white38, size: 40),
              SizedBox(height: 12),
              Text('No hay pistas adicionales\ndisponibles para este contenido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13)),
              SizedBox(height: 6),
              Text('Los streams con múltiples idiomas de audio\no subtítulos los mostrarán aquí automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 11)),
            ]))
        else ...[
          if (_audioTracks.isNotEmpty) ...[
            _SectionLabel(Icons.volume_up, 'Audio', AppColors.celeste),
            ..._audioTracks.map((t) => _TrackTile(track: t, isSelected: _selAudio == t.index,
              color: AppColors.celeste, onTap: () => _selectAudio(t.index))),
            if (_subTracks.isNotEmpty) const Divider(color: Colors.white10),
          ],
          if (_subTracks.isNotEmpty) ...[
            _SectionLabel(Icons.subtitles_outlined, 'Subtítulos', AppColors.azul),
            _TrackTile(track: _TrackInfo(-1, 'Ninguno', ''), isSelected: _selSub == -1,
              color: AppColors.azul, onTap: () => _selectSub(-1)),
            ..._subTracks.map((t) => _TrackTile(track: t, isSelected: _selSub == t.index,
              color: AppColors.azul, onTap: () => _selectSub(t.index))),
          ],
        ],
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _TrackInfo { final int index; final String label, language;
  const _TrackInfo(this.index, this.label, this.language); }

class _SectionLabel extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _SectionLabel(this.icon, this.text, this.color);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
    child: Row(children: [
      Icon(icon, color: color, size: 15), const SizedBox(width: 8),
      Text(text, style: TextStyle(color: color, fontSize: 12,
        fontWeight: FontWeight.bold, letterSpacing: 0.8)),
    ]));
}

class _TrackTile extends StatelessWidget {
  final _TrackInfo track; final bool isSelected; final Color color; final VoidCallback onTap;
  const _TrackTile({required this.track, required this.isSelected, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 150),
          width: 18, height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: isSelected ? color : Colors.white30, width: 2),
            color: isSelected ? color : Colors.transparent),
          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 11) : null),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70,
            fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          if (track.language.isNotEmpty)
            Text(track.language.toUpperCase(),
              style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ])),
        if (isSelected) Icon(Icons.check_circle, color: color, size: 16),
      ]),
    ));
}
