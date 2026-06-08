import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';

class SeriesScreen extends StatefulWidget {
  final XtreamService service;
  const SeriesScreen({super.key, required this.service});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Category> _categories = [];
  List<Series> _series = [];
  int _selectedCatIndex = 0;
  bool _loadingCats = true;
  bool _loadingSeries = false;

  final _catFocusNodes = <FocusNode>[];
  final _seriesFocusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final n in _catFocusNodes) n.dispose();
    for (final n in _seriesFocusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getSeriesCategories();
    if (!mounted) return;
    for (final _ in cats) _catFocusNodes.add(FocusNode());
    setState(() { _categories = cats; _loadingCats = false; });
    if (cats.isNotEmpty) _selectCategory(cats.first, 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    setState(() { _selectedCatIndex = index; _loadingSeries = true; _series = []; });
    for (final n in _seriesFocusNodes) n.dispose();
    _seriesFocusNodes.clear();
    final series = await widget.service.getSeries(categoryId: cat.id);
    if (!mounted) return;
    for (final _ in series) _seriesFocusNodes.add(FocusNode());
    setState(() { _series = series; _loadingSeries = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Categories panel
        Container(
          width: 220,
          color: const Color(0xFF0D1020),
          child: _loadingCats
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) => _CatItem(
                    name: _categories[i].name,
                    isSelected: _selectedCatIndex == i,
                    focusNode: _catFocusNodes[i],
                    autofocus: i == 0,
                    onSelect: () => _selectCategory(_categories[i], i),
                  ),
                ),
        ),
        Container(width: 1, color: Colors.white10),
        // Series grid
        Expanded(
          child: _loadingSeries
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : _series.isEmpty
                  ? const Center(child: Text('Sin series', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, childAspectRatio: 0.65,
                        crossAxisSpacing: 10, mainAxisSpacing: 10,
                      ),
                      itemCount: _series.length,
                      itemBuilder: (_, i) => _SeriesCard(
                        series: _series[i],
                        focusNode: _seriesFocusNodes.length > i ? _seriesFocusNodes[i] : null,
                        autofocus: i == 0,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _CatItem extends StatefulWidget {
  final String name;
  final bool isSelected;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onSelect;
  const _CatItem({required this.name, required this.isSelected, required this.focusNode, required this.autofocus, required this.onSelect});
  @override State<_CatItem> createState() => _CatItemState();
}
class _CatItemState extends State<_CatItem> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
  }
  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _focused;
    return InkWell(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      focusColor: Colors.transparent,
      onTap: widget.onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: widget.isSelected ? AppColors.buttonGradient : null,
          color: widget.isSelected ? null : (_focused ? Colors.white12 : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
        ),
        child: Text(widget.name,
          style: TextStyle(color: active ? Colors.white : AppColors.textSecondary,
            fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.normal),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SeriesCard extends StatefulWidget {
  final Series series;
  final FocusNode? focusNode;
  final bool autofocus;
  const _SeriesCard({required this.series, this.focusNode, this.autofocus = false});
  @override State<_SeriesCard> createState() => _SeriesCardState();
}
class _SeriesCardState extends State<_SeriesCard> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() { if (mounted) setState(() => _focused = widget.focusNode!.hasFocus); });
  }
  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      focusColor: Colors.transparent,
      onTap: () {}, // TODO: series detail screen
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: widget.series.cover.isNotEmpty
                ? CachedNetworkImage(imageUrl: widget.series.cover, fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) => Container(color: AppColors.card,
                        child: const Icon(Icons.tv, color: AppColors.celeste)))
                : Container(color: AppColors.card, child: const Icon(Icons.tv, color: AppColors.celeste)),
          )),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(widget.series.name,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}
