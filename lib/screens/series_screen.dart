import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'live_screen.dart' show sectionAppBar, CatTile;

class SeriesScreen extends StatefulWidget {
  final XtreamService service;
  const SeriesScreen({super.key, required this.service});
  @override State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Category> _categories = [];
  List<Series> _series = [];
  int _selectedCatIndex = 0;
  bool _loadingCats = true;
  bool _loadingSeries = false;
  final _catFocusNodes = <FocusNode>[];
  final _seriesFocusNodes = <FocusNode>[];

  static final _virtualCats = [
    Category(id: HistoryService.recentCatId, name: '🕐 Recientes'),
    Category(id: HistoryService.favCatId,    name: '❤️ Favoritos'),
  ];

  @override void initState() { super.initState(); _loadCategories(); }

  @override
  void dispose() {
    for (final n in _catFocusNodes) n.dispose();
    for (final n in _seriesFocusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getSeriesCategories();
    if (!mounted) return;
    final all = [..._virtualCats, ...cats];
    _catFocusNodes.addAll(List.generate(all.length, (_) => FocusNode()));
    setState(() { _categories = all; _loadingCats = false; });
    if (all.isNotEmpty) _selectCategory(all[0], 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    setState(() { _selectedCatIndex = index; _loadingSeries = true; _series = []; });
    for (final n in _seriesFocusNodes) n.dispose();
    _seriesFocusNodes.clear();

    List<Series> s;
    if (cat.id == HistoryService.recentCatId) {
      final data = await HistoryService.getRecent(HistoryService.series);
      s = data.map((d) => _seriesFromMap(d)).toList();
    } else if (cat.id == HistoryService.favCatId) {
      final data = await HistoryService.getFavorites(HistoryService.series);
      s = data.map((d) => _seriesFromMap(d)).toList();
    } else {
      s = await widget.service.getSeries(categoryId: cat.id);
    }
    if (!mounted) return;
    _seriesFocusNodes.addAll(List.generate(s.length, (_) => FocusNode()));
    setState(() { _series = s; _loadingSeries = false; });
  }

  Series _seriesFromMap(Map<String, String> d) => Series(
    id: d['id'] ?? '', name: d['name'] ?? '',
    cover: d['icon'] ?? '', categoryId: '');

  @override
  Widget build(BuildContext context) {
    final cols = R.gridCols(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: sectionAppBar(context, 'Series', Icons.tv_outlined, AppColors.morado),
      body: Row(children: [
        SizedBox(
          width: R.catPanelW(context),
          child: _loadingCats
            ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _categories.length,
                itemBuilder: (_, i) => CatTile(
                  name: _categories[i].name,
                  isSelected: _selectedCatIndex == i,
                  accentColor: i < _virtualCats.length ? Colors.amber : AppColors.morado,
                  focusNode: _catFocusNodes[i],
                  autofocus: i == 0,
                  onSelect: () => _selectCategory(_categories[i], i),
                )),
        ),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _loadingSeries
          ? const Center(child: CircularProgressIndicator(color: AppColors.morado))
          : _series.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_selectedCatIndex < _virtualCats.length ? Icons.inbox_outlined : Icons.tv_outlined,
                  color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text(_selectedCatIndex < _virtualCats.length ? 'Aún no hay nada aquí' : 'Sin series',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ]))
            : GridView.builder(
                padding: EdgeInsets.all(R.padding(context)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, childAspectRatio: 0.65,
                  crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: _series.length,
                itemBuilder: (_, i) => _SeriesCard(
                  series: _series[i],
                  focusNode: i < _seriesFocusNodes.length ? _seriesFocusNodes[i] : FocusNode(),
                  autofocus: i == 0,
                  onFavChanged: () => _selectCategory(_categories[_selectedCatIndex], _selectedCatIndex),
                ),
              )),
      ]),
    );
  }
}

class _SeriesCard extends StatefulWidget {
  final Series series;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onFavChanged;
  const _SeriesCard({required this.series, required this.focusNode,
    this.autofocus = false, required this.onFavChanged});
  @override State<_SeriesCard> createState() => _SeriesCardState();
}
class _SeriesCardState extends State<_SeriesCard> {
  bool _focused = false, _isFav = false;
  @override void initState() {
    super.initState();
    widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
    _loadFav();
  }
  Future<void> _loadFav() async {
    final f = await HistoryService.isFavorite(HistoryService.series, widget.series.id);
    if (mounted) setState(() => _isFav = f);
  }
  Future<void> _toggleFav() async {
    final newState = await HistoryService.toggleFavorite(
      HistoryService.series, widget.series.id,
      {'id': widget.series.id, 'name': widget.series.name, 'icon': widget.series.cover});
    if (mounted) { setState(() => _isFav = newState); widget.onFavChanged(); }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    InkWell(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      focusColor: Colors.transparent,
      onTap: () {
        HistoryService.addRecent(HistoryService.series,
          {'id': widget.series.id, 'name': widget.series.name, 'icon': widget.series.cover});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Próximamente: ${widget.series.name}'),
            duration: const Duration(seconds: 2)));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_focused ? 1.04 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focused ? AppColors.morado : Colors.white12, width: _focused ? 2 : 1),
          boxShadow: _focused ? [BoxShadow(color: AppColors.morado.withOpacity(0.5), blurRadius: 10)] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(fit: StackFit.expand, children: [
            widget.series.cover.isNotEmpty
              ? CachedNetworkImage(imageUrl: widget.series.cover, fit: BoxFit.cover,
                  placeholder: (_, __) => _ph(), errorWidget: (_, __, ___) => _ph())
              : _ph(),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                decoration: const BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Color(0xE6000000), Colors.transparent])),
                child: Text(widget.series.name,
                  style: TextStyle(color: Colors.white, fontSize: R.fs(context, 10), fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis))),
          ]),
        ),
      ),
    ),
    Positioned(top: 4, right: 4,
      child: GestureDetector(onTap: _toggleFav,
        child: Container(padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
          child: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
            color: _isFav ? Colors.red : Colors.white60, size: 14)))),
  ]);
  Widget _ph() => Container(color: AppColors.card,
    child: const Icon(Icons.tv_outlined, color: AppColors.morado, size: 28));
}
