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
  List<Channel> _channels = [];
  List<Movie> _movies = [];
  List<Series> _series = [];
  bool _loading = false;
  bool _searched = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    setState(() { _loading = true; _searched = false; });
    final query = q.trim().toLowerCase();
    final results = await Future.wait([
      widget.service.getLiveStreams(),
      widget.service.getMovies(),
      widget.service.getSeries(),
    ]);
    if (!mounted) return;
    setState(() {
      _channels = (results[0] as List<Channel>).where((c) => c.name.toLowerCase().contains(query)).toList();
      _movies   = (results[1] as List<Movie>).where((m) => m.name.toLowerCase().contains(query)).toList();
      _series   = (results[2] as List<Series>).where((s) => s.name.toLowerCase().contains(query)).toList();
      _loading = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Buscar en En Vivo, Películas y Series...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: AppColors.celeste),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () { _ctrl.clear(); setState(() { _searched = false; }); })
                : null,
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.celeste, width: 2)),
          ),
          onChanged: (v) => setState(() {}),
          onSubmitted: _search,
        ),
      ),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.celeste)))
      else if (!_searched)
        const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search, color: Colors.white24, size: 64),
          SizedBox(height: 12),
          Text('Escribe y presiona Enter para buscar', style: TextStyle(color: Colors.white38, fontSize: 15)),
        ])))
      else
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          if (_channels.isNotEmpty) ...[
            _SectionHeader(label: 'En Vivo', count: _channels.length),
            ..._channels.take(20).map((c) => _ResultTile(
              icon: Icons.live_tv, name: c.name, imageUrl: c.streamIcon, badge: 'EN VIVO',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                PlayerScreen(title: c.name, streamUrl: widget.service.liveStreamUrl(c.id)))),
            )),
          ],
          if (_movies.isNotEmpty) ...[
            _SectionHeader(label: 'Películas', count: _movies.length),
            ..._movies.take(20).map((m) => _ResultTile(
              icon: Icons.movie_outlined, name: m.name, imageUrl: m.streamIcon, badge: 'PELÍCULA',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                PlayerScreen(title: m.name, streamUrl: widget.service.movieStreamUrl(m.id, m.containerExtension)))),
            )),
          ],
          if (_series.isNotEmpty) ...[
            _SectionHeader(label: 'Series', count: _series.length),
            ..._series.take(20).map((s) => _ResultTile(
              icon: Icons.tv, name: s.name, imageUrl: s.cover, badge: 'SERIE',
              onTap: () {},
            )),
          ],
          if (_channels.isEmpty && _movies.isEmpty && _series.isEmpty)
            const Padding(padding: EdgeInsets.all(40),
              child: Center(child: Text('Sin resultados', style: TextStyle(color: Colors.white38, fontSize: 16)))),
        ])),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Row(children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.celeste.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(color: AppColors.celeste, fontSize: 12))),
    ]),
  );
}

class _ResultTile extends StatefulWidget {
  final IconData icon;
  final String name;
  final String imageUrl;
  final String badge;
  final VoidCallback onTap;
  const _ResultTile({required this.icon, required this.name, required this.imageUrl, required this.badge, required this.onTap});
  @override State<_ResultTile> createState() => _ResultTileState();
}
class _ResultTileState extends State<_ResultTile> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: widget.onTap,
    focusColor: Colors.transparent,
    onFocusChange: (f) => setState(() => _focused = f),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _focused ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: widget.imageUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: widget.imageUrl, width: 56, height: 40, fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholder(widget.icon),
                  errorWidget: (_, __, ___) => _placeholder(widget.icon))
              : _placeholder(widget.icon)),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.name,
          style: TextStyle(color: _focused ? Colors.white : AppColors.textPrimary, fontSize: 14),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.celeste.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.celeste.withOpacity(0.4))),
          child: Text(widget.badge, style: const TextStyle(color: AppColors.celeste, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    ),
  );
  Widget _placeholder(IconData icon) => Container(width: 56, height: 40, color: AppColors.card,
    child: Icon(icon, color: AppColors.celeste, size: 20));
}
