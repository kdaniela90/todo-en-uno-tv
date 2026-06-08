import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/movie.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';

class MoviesScreen extends StatefulWidget {
  final XtreamService service;
  const MoviesScreen({super.key, required this.service});
  @override State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Category> _categories = [];
  List<Movie> _movies = [];
  int _selectedCatIndex = 0;
  bool _loadingCats = true;
  bool _loadingMovies = false;
  final _catFocusNodes = <FocusNode>[];
  final _movieFocusNodes = <FocusNode>[];

  @override
  void initState() { super.initState(); _loadCategories(); }

  @override
  void dispose() {
    for (final n in _catFocusNodes) n.dispose();
    for (final n in _movieFocusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getVodCategories();
    if (!mounted) return;
    _catFocusNodes.addAll(List.generate(cats.length, (_) => FocusNode()));
    setState(() { _categories = cats; _loadingCats = false; });
    if (cats.isNotEmpty) _selectCategory(cats.first, 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    setState(() { _selectedCatIndex = index; _loadingMovies = true; _movies = []; });
    for (final n in _movieFocusNodes) n.dispose();
    _movieFocusNodes.clear();
    final m = await widget.service.getMovies(categoryId: cat.id);
    if (!mounted) return;
    _movieFocusNodes.addAll(List.generate(m.length, (_) => FocusNode()));
    setState(() { _movies = m; _loadingMovies = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _sectionAppBar(context, 'Películas', Icons.movie_outlined),
      body: Row(children: [
        _CatPanel(
          categories: _categories,
          selectedIndex: _selectedCatIndex,
          focusNodes: _catFocusNodes,
          loading: _loadingCats,
          onSelect: _selectCategory,
        ),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _loadingMovies
          ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
          : _movies.isEmpty
            ? const Center(child: Text('Sin películas', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, childAspectRatio: 0.65,
                  crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _movies.length,
                itemBuilder: (_, i) => _MovieCard(
                  movie: _movies[i],
                  service: widget.service,
                  focusNode: i < _movieFocusNodes.length ? _movieFocusNodes[i] : FocusNode(),
                  autofocus: i == 0,
                ),
              )),
      ]),
    );
  }
}

PreferredSizeWidget _sectionAppBar(BuildContext context, String title, IconData icon) =>
  AppBar(
    backgroundColor: const Color(0xFF080B14),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
      focusColor: AppColors.celeste.withOpacity(0.2),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.azul, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
    ]),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(color: Colors.white10, height: 1)),
  );

class _CatPanel extends StatelessWidget {
  final List<Category> categories;
  final int selectedIndex;
  final List<FocusNode> focusNodes;
  final bool loading;
  final void Function(Category, int) onSelect;
  const _CatPanel({required this.categories, required this.selectedIndex,
    required this.focusNodes, required this.loading, required this.onSelect});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
      : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: categories.length,
          itemBuilder: (_, i) => _CatTile(
            name: categories[i].name,
            isSelected: selectedIndex == i,
            focusNode: focusNodes[i],
            autofocus: i == 0,
            onSelect: () => onSelect(categories[i], i),
          )),
  );
}

class _CatTile extends StatefulWidget {
  final String name;
  final bool isSelected;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onSelect;
  const _CatTile({required this.name, required this.isSelected,
    required this.focusNode, required this.autofocus, required this.onSelect});
  @override State<_CatTile> createState() => _CatTileState();
}
class _CatTileState extends State<_CatTile> {
  bool _focused = false;
  @override void initState() {
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
            fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.normal),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _MovieCard extends StatefulWidget {
  final Movie movie;
  final XtreamService service;
  final FocusNode focusNode;
  final bool autofocus;
  const _MovieCard({required this.movie, required this.service,
    required this.focusNode, this.autofocus = false});
  @override State<_MovieCard> createState() => _MovieCardState();
}
class _MovieCardState extends State<_MovieCard> {
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
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
      title: widget.movie.name,
      streamUrl: widget.service.vodStreamUrl(widget.movie.id, widget.movie.containerExtension)))),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(_focused ? 1.06 : 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? AppColors.azul : Colors.white12, width: _focused ? 2.5 : 1),
        boxShadow: _focused ? [BoxShadow(color: AppColors.azul.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)] : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(fit: StackFit.expand, children: [
          widget.movie.streamIcon.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.movie.streamIcon, fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(), errorWidget: (_, __, ___) => _placeholder())
            : _placeholder(),
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Color(0xE6000000), Colors.transparent])),
              child: Text(widget.movie.name,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            )),
        ]),
      ),
    ),
  );
  Widget _placeholder() => Container(color: AppColors.card,
    child: const Icon(Icons.movie_outlined, color: AppColors.azul, size: 36));
}
