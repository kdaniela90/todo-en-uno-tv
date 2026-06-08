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
  @override State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Category> _categories = [];
  List<Channel> _channels = [];
  int _selectedCatIndex = 0;
  bool _loadingCats = true;
  bool _loadingChannels = false;
  final _catFocusNodes = <FocusNode>[];
  final _channelFocusNodes = <FocusNode>[];

  @override
  void initState() { super.initState(); _loadCategories(); }

  @override
  void dispose() {
    for (final n in _catFocusNodes) n.dispose();
    for (final n in _channelFocusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await widget.service.getLiveCategories();
    if (!mounted) return;
    _catFocusNodes.addAll(List.generate(cats.length, (_) => FocusNode()));
    setState(() { _categories = cats; _loadingCats = false; });
    if (cats.isNotEmpty) _selectCategory(cats.first, 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    setState(() { _selectedCatIndex = index; _loadingChannels = true; _channels = []; });
    for (final n in _channelFocusNodes) n.dispose();
    _channelFocusNodes.clear();
    final ch = await widget.service.getLiveStreams(categoryId: cat.id);
    if (!mounted) return;
    _channelFocusNodes.addAll(List.generate(ch.length, (_) => FocusNode()));
    setState(() { _channels = ch; _loadingChannels = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _sectionAppBar(context, 'En Vivo', Icons.live_tv),
      body: Row(children: [
        _CatPanel(
          categories: _categories,
          selectedIndex: _selectedCatIndex,
          focusNodes: _catFocusNodes,
          loading: _loadingCats,
          onSelect: _selectCategory,
        ),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _loadingChannels
          ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
          : _channels.isEmpty
            ? const Center(child: Text('Sin canales', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: _channels.length,
                itemBuilder: (_, i) => _ChannelTile(
                  channel: _channels[i],
                  service: widget.service,
                  focusNode: i < _channelFocusNodes.length ? _channelFocusNodes[i] : FocusNode(),
                  autofocus: i == 0,
                ),
              )),
      ]),
    );
  }
}

// ─── Shared AppBar ────────────────────────────────────────────────────────────
PreferredSizeWidget _sectionAppBar(BuildContext context, String title, IconData icon) =>
  AppBar(
    backgroundColor: const Color(0xFF080B14),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
      focusColor: AppColors.celeste.withOpacity(0.2),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.celeste, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
    ]),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(color: Colors.white10, height: 1)),
  );

// ─── Category Panel ───────────────────────────────────────────────────────────
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

// ─── Channel Tile ─────────────────────────────────────────────────────────────
class _ChannelTile extends StatefulWidget {
  final Channel channel;
  final XtreamService service;
  final FocusNode focusNode;
  final bool autofocus;
  const _ChannelTile({required this.channel, required this.service,
    required this.focusNode, this.autofocus = false});
  @override State<_ChannelTile> createState() => _ChannelTileState();
}
class _ChannelTileState extends State<_ChannelTile> {
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
      title: widget.channel.name,
      streamUrl: widget.service.liveStreamUrl(widget.channel.id)))),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _focused ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
      ),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: widget.channel.streamIcon.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.channel.streamIcon, width: 60, height: 44, fit: BoxFit.contain,
                placeholder: (_, __) => _iconBox(), errorWidget: (_, __, ___) => _iconBox())
            : _iconBox()),
        const SizedBox(width: 14),
        Expanded(child: Text(widget.channel.name,
          style: TextStyle(color: _focused ? Colors.white : AppColors.textPrimary,
            fontSize: 15, fontWeight: _focused ? FontWeight.w600 : FontWeight.normal),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.withOpacity(0.5))),
          child: const Text('● EN VIVO', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    ),
  );
  Widget _iconBox() => Container(width: 60, height: 44,
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(6)),
    child: const Icon(Icons.tv, color: AppColors.celeste, size: 22));
}
