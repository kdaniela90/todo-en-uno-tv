import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  final XtreamService service;
  const SearchScreen({super.key, required this.service});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _fieldFocus = FocusNode();
  List<Channel> _liveResults = [];
  List<Movie> _movieResults = [];
  List<Series> _seriesResults = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() { _ctrl.dispose(); _fieldFocus.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return;
    setState(() { _loading = true; _searched = false; });
    final results = await Future.wait([
      widget.service.getLiveStreams(),
      widget.service.getMovies(),
      widget.service.getSeries(),
    ]);
    if (!mounted) return;
    setState(() {
      _liveResults = (results[0] as List<Channel>).where((c) => c.name.toLowerCase().contains(query)).toList();
      _movieResults = (results[1] as List<Movie>).where((m) => m.name.toLowerCase().contains(query)).toList();
      _seriesResults = (results[2] as List<Series>).where((s) => s.name.toLowerCase().contains(query)).toList();
      _loading = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _liveResults.length + _movieResults.length + _seriesResults.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          focusColor: AppColors.celeste.withOpacity(0.2),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search, color: AppColors.celeste, size: 20),
          SizedBox(width: 8),
          Text('Buscar', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1),
          child: Divider(color: Colors.white10, height: 1)),
      ),
      body: Column(children: [
        // Search field
        Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.celeste.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Padding(padding: EdgeInsets.only(left: 16), child: Icon(Icons.search, color: AppColors.textSecondary)),
            Expanded(child: TextField(
              controller: _ctrl,
              focusNode: _fieldFocus,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Buscar canales, películas, series...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              onSubmitted: _search,
            )),
            if (_loading) const Padding(padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.celeste))),
            if (!_loading && _ctrl.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.celeste),
                onPressed: () => _search(_ctrl.text)),
          ]),
        ),

        // Results
        Expanded(child: !_searched
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.travel_explore, color: AppColors.textSecondary, size: 56),
              SizedBox(height: 16),
              Text('Escribe algo para buscar', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ]))
          : total == 0
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_off, color: AppColors.textSecondary, size: 56),
                const SizedBox(height: 16),
                Text('Sin resultados para "${_ctrl.text}"',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ]))
            : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                if (_liveResults.isNotEmpty) ...[
                  _SectionHeader('En Vivo', _liveResults.length, AppColors.celeste, Icons.live_tv),
                  ..._liveResults.map((c) => _ResultTile(
                    title: c.name, imageUrl: c.streamIcon,
                    color: AppColors.celeste, icon: Icons.live_tv,
                    badge: 'EN VIVO', badgeColor: Colors.red,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
                      title: c.name, streamUrl: widget.service.liveStreamUrl(c.id)))))),
                ],
                if (_movieResults.isNotEmpty) ...[
                  _SectionHeader('Películas', _movieResults.length, AppColors.azul, Icons.movie_outlined),
                  ..._movieResults.map((m) => _ResultTile(
                    title: m.name, imageUrl: m.streamIcon,
                    color: AppColors.azul, icon: Icons.movie_outlined,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
                      title: m.name, streamUrl: widget.service.vodStreamUrl(m.id, m.containerExtension)))))),
                ],
                if (_seriesResults.isNotEmpty) ...[
                  _SectionHeader('Series', _seriesResults.length, AppColors.morado, Icons.tv_outlined),
                  ..._seriesResults.map((s) => _ResultTile(
                    title: s.name, imageUrl: s.cover,
                    color: AppColors.morado, icon: Icons.tv_outlined,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Próximamente: ${s.name}'))))),
                ],
                const SizedBox(height: 40),
              ]),
        ),
      ]),
    );
  }
}

Widget _SectionHeader(String label, int count, Color color, IconData icon) => Padding(
  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
  child: Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
    const SizedBox(width: 8),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))),
  ]),
);

class _ResultTile extends StatefulWidget {
  final String title, imageUrl;
  final Color color;
  final IconData icon;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _ResultTile({required this.title, required this.imageUrl, required this.color,
    required this.icon, required this.onTap, this.badge, this.badgeColor});
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
  Widget build(BuildContext context) => InkWell(
    focusNode: _fn,
    focusColor: Colors.transparent,
    onTap: widget.onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _focused ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? widget.color : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: widget.imageUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.imageUrl, width: 64, height: 48, fit: BoxFit.cover,
                placeholder: (_, __) => _imgBox(), errorWidget: (_, __, ___) => _imgBox())
            : _imgBox()),
        const SizedBox(width: 14),
        Expanded(child: Text(widget.title,
          style: TextStyle(color: _focused ? Colors.white : AppColors.textPrimary,
            fontSize: 14, fontWeight: _focused ? FontWeight.w600 : FontWeight.normal),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (widget.badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (widget.badgeColor ?? widget.color).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: (widget.badgeColor ?? widget.color).withOpacity(0.6))),
            child: Text(widget.badge!, style: TextStyle(
              color: widget.badgeColor ?? widget.color, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    ),
  );
  Widget _imgBox() => Container(width: 64, height: 48, color: AppColors.card,
    child: Icon(widget.icon, color: widget.color, size: 22));
}
