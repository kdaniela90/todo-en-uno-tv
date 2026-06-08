import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'live_screen.dart' show sectionAppBar, _CatTile;

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
    _catFocusNodes.addAll(List.generate(cats.length, (_) => FocusNode()));
    setState(() { _categories = cats; _loadingCats = false; });
    if (cats.isNotEmpty) _selectCategory(cats.first, 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    setState(() { _selectedCatIndex = index; _loadingSeries = true; _series = []; });
    for (final n in _seriesFocusNodes) n.dispose();
    _seriesFocusNodes.clear();
    final s = await widget.service.getSeries(categoryId: cat.id);
    if (!mounted) return;
    _seriesFocusNodes.addAll(List.generate(s.length, (_) => FocusNode()));
    setState(() { _series = s; _loadingSeries = false; });
  }

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
                itemBuilder: (_, i) => _CatTile(
                  name: _categories[i].name,
                  isSelected: _selectedCatIndex == i,
                  accentColor: AppColors.morado,
                  focusNode: _catFocusNodes[i],
                  autofocus: i == 0,
                  onSelect: () => _selectCategory(_categories[i], i),
                )),
        ),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _loadingSeries
          ? const Center(child: CircularProgressIndicator(color: AppColors.morado))
          : _series.isEmpty
            ? const Center(child: Text('Sin series', style: TextStyle(color: AppColors.textSecondary)))
            : GridView.builder(
                padding: EdgeInsets.all(R.padding(context)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, childAspectRatio: 0.65,
                  crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: _series.length,
                itemBuilder: (_, i) => _SeriesCard(
                  series: _series[i],
                  focusNode: i < _seriesFocusNodes.length ? _seriesFocusNodes[i] : FocusNode(),
                  autofocus: i == 0,
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
  const _SeriesCard({required this.series, required this.focusNode, this.autofocus = false});
  @override State<_SeriesCard> createState() => _SeriesCardState();
}
class _SeriesCardState extends State<_SeriesCard> {
  bool _focused = false;
  @override void initState() {
    super.initState();
    widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
  }
  @override
  Widget build(BuildContext context) => InkWell(
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    focusColor: Colors.transparent,
    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Próximamente: ${widget.series.name}'), duration: const Duration(seconds: 2))),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(_focused ? 1.05 : 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? AppColors.morado : Colors.white12, width: _focused ? 2.5 : 1),
        boxShadow: _focused ? [BoxShadow(color: AppColors.morado.withOpacity(0.5), blurRadius: 12)] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(fit: StackFit.expand, children: [
          widget.series.cover.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.series.cover, fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(), errorWidget: (_, __, ___) => _placeholder())
            : _placeholder(),
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xE6000000), Colors.transparent])),
              child: Text(widget.series.name,
                style: TextStyle(color: Colors.white, fontSize: R.fs(context, 11), fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis))),
        ]),
      ),
    ),
  );
  Widget _placeholder() => Container(color: AppColors.card,
    child: const Icon(Icons.tv_outlined, color: AppColors.morado, size: 32));
}
