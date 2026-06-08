import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/channel.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';

class LiveScreen extends StatefulWidget {
  final XtreamService service;
  const LiveScreen({super.key, required this.service});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Category> _categories = [];
  List<Channel> _channels = [];
  Category? _selectedCategory;
  bool _loadingCategories = true;
  bool _loadingChannels = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getLiveCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loadingCategories = false;
    });
    if (cats.isNotEmpty) _selectCategory(cats.first);
  }

  Future<void> _selectCategory(Category cat) async {
    setState(() { _selectedCategory = cat; _loadingChannels = true; });
    final channels = await widget.service.getLiveStreams(categoryId: cat.id);
    if (!mounted) return;
    setState(() { _channels = channels; _loadingChannels = false; });
  }

  List<Channel> get _filtered {
    if (_search.isEmpty) return _channels;
    return _channels
        .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar canal...',
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
        // Categories horizontal list
        if (_loadingCategories)
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
        // Channels list
        Expanded(
          child: _loadingChannels
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('Sin canales', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _ChannelTile(
                        channel: _filtered[i],
                        service: widget.service,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final XtreamService service;

  const _ChannelTile({required this.channel, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: channel.streamIcon.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: channel.streamIcon,
                width: 56,
                height: 40,
                fit: BoxFit.contain,
                placeholder: (_, __) => Container(
                  width: 56, height: 40,
                  color: AppColors.card,
                  child: const Icon(Icons.tv, color: AppColors.celeste, size: 20),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 56, height: 40,
                  color: AppColors.card,
                  child: const Icon(Icons.tv, color: AppColors.celeste, size: 20),
                ),
              )
            : Container(
                width: 56, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tv, color: AppColors.celeste, size: 20),
              ),
      ),
      title: Text(
        channel.name,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: const Text(
          '● EN VIVO',
          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: channel.name,
            streamUrl: service.liveStreamUrl(channel.id),
          ),
        ),
      ),
    );
  }
}
