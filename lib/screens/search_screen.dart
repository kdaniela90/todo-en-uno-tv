import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'live_screen.dart' show sectionAppBar;
import 'player_screen.dart';
import 'movie_detail_screen.dart';
import 'series_detail_screen.dart';

enum _SearchMode { title, actor }

class SearchScreen extends StatefulWidget {
  final XtreamService service;
  const SearchScreen({super.key, required this.service});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl        = TextEditingController();
  final _fieldFocus  = FocusNode();
  _SearchMode _mode  = _SearchMode.title;

  List<Channel> _liveResults   = [];
  List<Movie>   _movieResults  = [];
  List<Series>  _seriesResults = [];
  bool _loading  = false;
  bool _searched = false;

  @override void dispose() { _ctrl.dispose(); _fieldFocus.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return;
    setState(() { _loading = true; _searched = false; });

    if (_mode == _SearchMode.title) {
      // Búsqueda por título en las 3 secciones
      final results = await Future.wait([
        widget.service.getLiveStreams(),
        widget.service.getMovies(),
        widget.service.getSeries(),
      ]);
      if (!mounted) return;
      setState(() {
        _liveResults   = (results[0] as List<Channel>).where((c) => c.name.toLowerCase().contains(query)).toList();
        _movieResults  = (results[1] as List<Movie>).where((m)   => m.name.toLowerCase().contains(query)).toList();
        _seriesResults = (results[2] as List<Series>).where((s)  => s.name.toLowerCase().contains(query)).toList();
        _loading = false; _searched = true;
      });
    } else {
      // Búsqueda por actor — solo películas (cast viene en el listing básico)
      final movies = await widget.service.getMovies();
      if (!mounted) return;
      setState(() {
        _liveResults   = [];
        _seriesResults = [];
        _movieResults  = movies.where((m) =>
          m.cast.toLowerCase().contains(query) ||
          m.name.toLowerCase().contains(query)).toList();
        // Ordenar: primero los que coincidan en cast, luego solo en título
        _movieResults.sort((a, b) {
          final aInCast = a.cast.toLowerCase().contains(query) ? 0 : 1;
          final bInCast = b.cast.toLowerCase().contains(query) ? 0 : 1;
          return aInCast.compareTo(bInCast);
        });
        _loading = false; _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _liveResults.length + _movieResults.length + _seriesResults.length;
    final p = R.padding(context);
    final isPhone = R.isPhone(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: sectionAppBar(context, 'Buscar', Icons.search, AppColors.celeste),
      body: Column(children: [

        // ── Campo de búsqueda ────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(p + 6, p + 6, p + 6, 0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.celeste.withOpacity(0.3)),
            ),
            child: Row(children: [
              Padding(padding: EdgeInsets.only(left: p + 2),
                child: const Icon(Icons.search, color: AppColors.textSecondary)),
              Expanded(child: TextField(
                controller: _ctrl,
                focusNode: _fieldFocus,
                autofocus: false,
                style: TextStyle(color: Colors.white, fontSize: R.fs(context, 15)),
                decoration: InputDecoration(
                  hintText: _mode == _SearchMode.title
                    ? 'Canales, películas, series...'
                    : 'Nombre del actor o actriz...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: p, vertical: 14),
                ),
                onSubmitted: _search,
              )),
              if (_loading)
                Padding(padding: EdgeInsets.only(right: p),
                  child: const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.celeste)))
              else if (_ctrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.celeste),
                  onPressed: () => _search(_ctrl.text)),
            ]),
          ),
        ),

        // ── Toggle: Título / Actor ───────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: p + 6, vertical: 10),
          child: Row(children: [
            _ModeChip(
              label: 'Por título',
              icon: Icons.title,
              selected: _mode == _SearchMode.title,
              color: AppColors.celeste,
              onTap: () {
                if (_mode != _SearchMode.title) {
                  FocusScope.of(context).unfocus();
                  setState(() { _mode = _SearchMode.title; _searched = false; });
                  _ctrl.clear();
                }
              },
            ),
            const SizedBox(width: 10),
            _ModeChip(
              label: 'Por actor',
              icon: Icons.person_search,
              selected: _mode == _SearchMode.actor,
              color: const Color(0xFFE86C2A),
              onTap: () {
                if (_mode != _SearchMode.actor) {
                  FocusScope.of(context).unfocus();
                  setState(() { _mode = _SearchMode.actor; _searched = false; });
                  _ctrl.clear();
                }
              },
            ),
            if (_mode == _SearchMode.actor && !isPhone)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('Busca en películas por nombre del reparto',
                  style: const TextStyle(color: Colors.white38, fontSize: 11))),
          ]),
        ),

        // ── Resultados ───────────────────────────────────────────────────────
        Expanded(child: !_searched
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _mode == _SearchMode.actor ? Icons.person_search : Icons.travel_explore,
                color: AppColors.textSecondary,
                size: isPhone ? 40 : 56),
              const SizedBox(height: 14),
              Text(
                _mode == _SearchMode.actor
                  ? 'Escribe el nombre de un actor'
                  : 'Escribe algo para buscar',
                style: TextStyle(color: AppColors.textSecondary, fontSize: R.fs(context, 15))),
              if (_mode == _SearchMode.actor) ...[
                const SizedBox(height: 6),
                const Text('Los resultados dependen de\nlos datos disponibles del proveedor',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
              ],
            ]))
          : total == 0
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off, color: AppColors.textSecondary, size: isPhone ? 40 : 56),
                const SizedBox(height: 14),
                Text('Sin resultados para "${_ctrl.text}"',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: R.fs(context, 15))),
                if (_mode == _SearchMode.actor) ...[
                  const SizedBox(height: 8),
                  const Text('Prueba con el apellido o solo parte del nombre',
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ]))
            : ListView(padding: EdgeInsets.symmetric(horizontal: p + 6), children: [
                if (_liveResults.isNotEmpty) ...[
                  _SectionHeader('En Vivo', _liveResults.length, AppColors.celeste, Icons.live_tv),
                  ..._liveResults.map((c) => _ResultTile(
                    title: c.name, subtitle: null, imageUrl: c.streamIcon,
                    color: AppColors.celeste, icon: Icons.live_tv,
                    badge: 'EN VIVO', badgeColor: Colors.red,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      PlayerScreen(title: c.name,
                        streamUrl: widget.service.liveStreamUrl(c.id)))))),
                ],
                if (_movieResults.isNotEmpty) ...[
                  _SectionHeader('Películas', _movieResults.length, AppColors.azul, Icons.movie_outlined),
                  ..._movieResults.map((m) {
                    // En modo actor, muestra el cast como subtítulo para confirmar el match
                    final sub = (_mode == _SearchMode.actor && m.cast.isNotEmpty)
                      ? m.cast : null;
                    return _ResultTile(
                      title: m.name, subtitle: sub, imageUrl: m.streamIcon,
                      color: AppColors.azul, icon: Icons.movie_outlined,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        MovieDetailScreen(movie: m, service: widget.service))));
                  }),
                ],
                if (_seriesResults.isNotEmpty) ...[
                  _SectionHeader('Series', _seriesResults.length, AppColors.morado, Icons.tv_outlined),
                  ..._seriesResults.map((s) => _ResultTile(
                    title: s.name, subtitle: null, imageUrl: s.cover,
                    color: AppColors.morado, icon: Icons.tv_outlined,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      SeriesDetailScreen(series: s, service: widget.service))))),
                ],
                const SizedBox(height: 40),
              ]),
        ),
      ]),
    );
  }
}

// ─── Mode Chip ────────────────────────────────────────────────────────────────
class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.icon,
    required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : Colors.white24,
          width: selected ? 2 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: selected ? color : Colors.white54, size: 15),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          color: selected ? color : Colors.white60,
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ]),
    ),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────
Widget _SectionHeader(String label, int count, Color color, IconData icon) =>
  Builder(builder: (ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: color,
        fontSize: R.fs(ctx, 14), fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.bold))),
    ]),
  ));

// ─── Result Tile ──────────────────────────────────────────────────────────────
class _ResultTile extends StatefulWidget {
  final String title;
  final String? subtitle;   // cast line in actor mode
  final String imageUrl;
  final Color color;
  final IconData icon;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _ResultTile({required this.title, required this.subtitle,
    required this.imageUrl, required this.color, required this.icon,
    required this.onTap, this.badge, this.badgeColor});
  @override State<_ResultTile> createState() => _ResultTileState();
}
class _ResultTileState extends State<_ResultTile> {
  bool _focused = false;
  final _fn = FocusNode();
  @override void initState() {
    super.initState();
    _fn.addListener(() { if (mounted) setState(() => _focused = _fn.hasFocus); });
  }
  @override void dispose() { _fn.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isPhone = R.isPhone(context);
    final imgW = isPhone ? 50.0 : 64.0;
    final imgH = isPhone ? 36.0 : 48.0;
    return InkWell(
      focusNode: _fn,
      focusColor: Colors.transparent,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 8 : 12, vertical: isPhone ? 8 : 10),
        decoration: BoxDecoration(
          color: _focused ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused ? widget.color : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: widget.imageUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: widget.imageUrl,
                  width: imgW, height: imgH, fit: BoxFit.cover,
                  placeholder: (_, __) => _imgBox(imgW, imgH),
                  errorWidget: (_, __, ___) => _imgBox(imgW, imgH))
              : _imgBox(imgW, imgH)),
          SizedBox(width: isPhone ? 10 : 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                style: TextStyle(
                  color: _focused ? Colors.white : AppColors.textPrimary,
                  fontSize: R.fs(context, 14),
                  fontWeight: _focused ? FontWeight.w600 : FontWeight.normal),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              // Subtítulo de cast en modo actor
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.person, color: Colors.white38, size: 11),
                  const SizedBox(width: 4),
                  Expanded(child: Text(widget.subtitle!,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ],
          )),
          if (widget.badge != null && !isPhone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (widget.badgeColor ?? widget.color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (widget.badgeColor ?? widget.color).withOpacity(0.6))),
              child: Text(widget.badge!,
                style: TextStyle(
                  color: widget.badgeColor ?? widget.color,
                  fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
  Widget _imgBox(double w, double h) => Container(width: w, height: h,
    color: AppColors.card, child: Icon(widget.icon, color: widget.color, size: 20));
}
