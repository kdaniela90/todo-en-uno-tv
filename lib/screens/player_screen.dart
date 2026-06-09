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
        // Habilita el avance/retroceso explícitamente
        allowedScreenSleep: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.celeste,
          handleColor: AppColors.gradStart,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
      );
      setState(() {});
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
    setState(() => _showBar = true);
    _startHideTimer();
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
    body: Stack(children: [
      // ── Reproductor — maneja sus propios gestos (seek, pausa, volumen)
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

      // ── Zona de tap translúcida — no bloquea gestos de chewie
      if (!_hasError && _chewieController != null)
        Positioned.fill(
          child: GestureDetector(
            // translucent: nuestro onTap dispara Y los eventos siguen a chewie
            behavior: HitTestBehavior.translucent,
            onTap: _onTapScreen,
            child: const SizedBox.expand(),
          ),
        ),

      // ── Barra superior auto-ocultable
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

// ─── Panel de audio/subtítulos ────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final VideoPlayerController videoController;
  const _SettingsSheet({required this.videoController});
  @override State<_SettingsSheet> createState() => _SettingsSheetState();
}
class _SettingsSheetState extends State<_SettingsSheet> {
  List<_Tk> _audio = [], _subs = [];
  int _selA = 0, _selS = -1;

  @override void initState() { super.initState(); _load(); }

  void _load() {
    try {
      final dynamic v = widget.videoController.value;
      final dynamic raw = v.tracks;
      if (raw is List) {
        final a = <_Tk>[], s = <_Tk>[];
        for (int i = 0; i < raw.length; i++) {
          try {
            final t = raw[i]; final tp = t.trackType.toString();
            final lb = (t.label ?? '').toString(); final lg = (t.language ?? '').toString();
            if (tp.contains('audio')) a.add(_Tk(i, lb.isNotEmpty ? lb : 'Pista ${a.length+1}', lg));
            else if (tp.contains('text')) s.add(_Tk(i, lb.isNotEmpty ? lb : 'Sub ${s.length+1}', lg));
          } catch (_) {}
        }
        if (mounted) setState(() { _audio = a; _subs = s; });
      }
    } catch (_) {}
  }

  void _setA(int i) { try { (widget.videoController as dynamic).setTrackParameters('audio',i); } catch(_){} setState(()=>_selA=i); }
  void _setS(int i) { try { (widget.videoController as dynamic).setTrackParameters('text',i); } catch(_){} setState(()=>_selS=i); }

  @override Widget build(BuildContext context) {
    final has = _audio.isNotEmpty || _subs.isNotEmpty;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0D1020),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top:10,bottom:2), width:36, height:4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const Padding(padding: EdgeInsets.symmetric(horizontal:20,vertical:12),
          child: Row(children:[Icon(Icons.settings,color:AppColors.celeste,size:20),SizedBox(width:10),
            Text('Audio y subtítulos',style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.bold))])),
        const Divider(color:Colors.white10,height:1),
        if (!has) const Padding(padding: EdgeInsets.symmetric(vertical:28,horizontal:24),
          child: Column(children:[
            Icon(Icons.info_outline,color:Colors.white38,size:40), SizedBox(height:12),
            Text('No hay pistas adicionales\ndisponibles para este contenido.',
              textAlign:TextAlign.center, style:TextStyle(color:Colors.white54,fontSize:13)),
            SizedBox(height:6),
            Text('Disponible en streams con múltiples\nidiomas de audio o subtítulos integrados.',
              textAlign:TextAlign.center, style:TextStyle(color:Colors.white30,fontSize:11)),
          ]))
        else ...[
          if (_audio.isNotEmpty) ...[ _Lbl(Icons.volume_up,'Audio',AppColors.celeste),
            ..._audio.map((t)=>_Opt(t,_selA==t.i,AppColors.celeste,()=>_setA(t.i))),
            if (_subs.isNotEmpty) const Divider(color:Colors.white10)],
          if (_subs.isNotEmpty) ...[ _Lbl(Icons.subtitles_outlined,'Subtítulos',AppColors.azul),
            _Opt(_Tk(-1,'Ninguno',''),_selS==-1,AppColors.azul,()=>_setS(-1)),
            ..._subs.map((t)=>_Opt(t,_selS==t.i,AppColors.azul,()=>_setS(t.i)))],
        ],
        const SizedBox(height:16),
      ]));
  }
}
class _Tk { final int i; final String lb,lg; const _Tk(this.i,this.lb,this.lg); }
Widget _Lbl(IconData ic, String txt, Color c) => Padding(padding:const EdgeInsets.fromLTRB(20,14,20,4),
  child:Row(children:[Icon(ic,color:c,size:15),SizedBox(width:8),
    Text(txt,style:TextStyle(color:c,fontSize:12,fontWeight:FontWeight.bold,letterSpacing:0.8))]));
Widget _Opt(_Tk t, bool sel, Color c, VoidCallback onTap) => InkWell(onTap:onTap,
  child:Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:11),
    child:Row(children:[
      AnimatedContainer(duration:const Duration(milliseconds:150),width:18,height:18,
        decoration:BoxDecoration(shape:BoxShape.circle,
          border:Border.all(color:sel?c:Colors.white30,width:2),color:sel?c:Colors.transparent),
        child:sel?const Icon(Icons.check,color:Colors.white,size:11):null),
      const SizedBox(width:14),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t.lb,style:TextStyle(color:sel?Colors.white:Colors.white70,fontSize:13,
          fontWeight:sel?FontWeight.w600:FontWeight.normal)),
        if(t.lg.isNotEmpty) Text(t.lg.toUpperCase(),
          style:const TextStyle(color:Colors.white38,fontSize:10,letterSpacing:1)),
      ])),
      if(sel) Icon(Icons.check_circle,color:c,size:16),
    ])));
