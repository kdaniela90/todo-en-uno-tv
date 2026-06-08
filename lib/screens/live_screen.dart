import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _selectedCatIndex = 0;

  // Focus nodes
  final _categoryFocusNodes = <FocusNode>[];
  final _channelFocusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final n in _categoryFocusNodes) n.dispose();
    for (final n in _channelFocusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getLiveCategories();
    if (!mounted) return;
    for (final _ in cats) _categoryFocusNodes.add(FocusNode());
    setState(() {
      _categories = cats;
      _loadingCategories = false;
    });
    if (cats.isNotEmpty) _selectCategory(cats.first, 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    setState(() {
      _selectedCategory = cat;
      _selectedCatIndex = index;
      _loadingChannels = true;
      _channels = [];
    });
    for (final n in _channelFocusNodes) n.dispose();
    _channelFocusNodes.clear();

    final channels = await widget.service.getLiveStreams(categoryId: cat.id);
    if (!mounted) return;
    for (final _ in channels) _channelFocusNodes.add(FocusNode());
    setState(() {
      _channels = channels;
      _loadingChannels = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LEFT: Categories panel
        Container(
          width: 220,
          color: const Color(0xFF0D1020),
          child: _loadingCategories
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) => _CategoryItem(
                    category: _categories[i],
                    isSelected: _selectedCatIndex == i,
                    focusNode: _categoryFocusNodes[i],
                    autofocus: i == 0,
                    onSelect: () => _selectCategory(_categories[i], i),
                  ),
                ),
        ),
        // Divider
        Container(width: 1, color: Colors.white10),
        // RIGHT: Channels list
        Expanded(
          child: _loadingChannels
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : _channels.isEmpty
                  ? const Center(
                      child: Text('Sin canales', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: _channels.length,
                      itemBuilder: (_, i) => _ChannelTile(
                        channel: _channels[i],
                        service: widget.service,
                        focusNode: _channelFocusNodes.length > i ? _channelFocusNodes[i] : null,
                        autofocus: i == 0,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final Category category;
  final bool isSelected;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onSelect;

  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.focusNode,
    required this.autofocus,
    required this.onSelect,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
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
          border: Border.all(
            color: _focused ? AppColors.celeste : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.live_tv,
              size: 16,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.category.name,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  final Channel channel;
  final XtreamService service;
  final FocusNode? focusNode;
  final bool autofocus;

  const _ChannelTile({
    required this.channel,
    required this.service,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode!.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      focusColor: Colors.transparent,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            title: widget.channel.name,
            streamUrl: widget.service.liveStreamUrl(widget.channel.id),
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _focused ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _focused ? AppColors.celeste : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: widget.channel.streamIcon.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.channel.streamIcon,
                      width: 60,
                      height: 44,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => _iconPlaceholder(),
                      errorWidget: (_, __, ___) => _iconPlaceholder(),
                    )
                  : _iconPlaceholder(),
            ),
            const SizedBox(width: 14),
            // Name
            Expanded(
              child: Text(
                widget.channel.name,
                style: TextStyle(
                  color: _focused ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: _focused ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // EN VIVO badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: const Text(
                '● EN VIVO',
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder() => Container(
    width: 60, height: 44,
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.tv, color: AppColors.celeste, size: 22),
  );
}
