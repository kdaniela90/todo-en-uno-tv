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

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Category> _categories = [];
  List<Movie> _movies = [];
  Category? _selectedCategory;
  bool _loadingCats = true;
  bool _loadingMovies = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getMovieCategories();
    if (!mounted) return;
    setState(() { _categories = cats; _loadingCats = false; });
    if (cats.isNotEmpty) _selectCategory(cats.first);
  }

  Future<void> _selectCategory(Category cat) async {
    setState(() { _selectedCategory = cat; _loadingMovies = true; });
    final movies = await widget.service.getMovies(categoryId: cat.id);
    if (!mounted) return;
    setState(() { _movies = movies; _loadingMovies = false; });
  }

  List<Movie> get _filtered {
    if (_search.isEmpty) return _movies;
    return _movies
        .where((m) => m.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar película...',
              prefixIcon: const Icon(Icons.search, color: AppColors.celeste),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (_loadingCats)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(color: AppColors.celeste),
          )
        else
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory?.id == cat.id;
                return GestureDetector(
                  onTap: () => _selectCategory(cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.buttonGradient : null,
                      color: isSelected ? null : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingMovies
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('Sin películas', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _MovieCard(
                        movie: _filtered[i],
                        service: widget.service,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final XtreamService service;
  const _MovieCard({required this.movie, required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: movie.name,
            streamUrl: service.movieStreamUrl(movie.id, movie.containerExtension),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: movie.streamIcon.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.streamIcon,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: AppColors.card),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.card,
                        child: const Icon(Icons.movie, color: AppColors.celeste),
                      ),
                    )
                  : Container(
                      color: AppColors.card,
                      child: const Icon(Icons.movie, color: AppColors.celeste),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            movie.name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
