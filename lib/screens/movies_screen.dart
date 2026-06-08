import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/movie.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'live_screen.dart' show sectionAppBar, _CatTile;
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

  @override void initState() { super.initState(); _loadCategories(); }

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
    final cols = R.gridCols(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: sectionAppBar(context, 'Películas', Icons.movie_outlined, AppColors.azul),
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
                  accentColor: AppColors.azul,
                  focusNode: _catFocusNodes[i],
                  autofocus: i == 0,
                  onSelect: () => _selectCategory(_categories[i], i),
                )),
        ),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _loadingMovies
          ? const Center(child: CircularProgressIndicator(color: AppColors.azul))
          : _movies.isEmpty
            ? const Center(child: Text('Sin películas', style: TextStyle(color: AppColors.textSecondary)))
            : GridView.builder(
                padding: EdgeInsets.all(R.padding(context)),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, childAspectRatio: 0.65,
                  crossAxisSpacing: 8, mainAxisSpacing: 8),
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
      transform: Matrix4.identity()..scale(_focused ? 1.05 : 1.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? AppColors.azul : Colors.white12, width: _focused ? 2.5 : 1),
        boxShadow: _focused ? [BoxShadow(color: AppColors.azul.withOpacity(0.5), blurRadius: 12)] : [],
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xE6000000), Colors.transparent])),
              child: Text(widget.movie.name,
                style: TextStyle(color: Colors.white, fontSize: R.fs(context, 11), fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis))),
        ]),
      ),
    ),
  );
  Widget _placeholder() => Container(color: AppColors.card,
    child: const Icon(Icons.movie_outlined, color: AppColors.azul, size: 32));
}
