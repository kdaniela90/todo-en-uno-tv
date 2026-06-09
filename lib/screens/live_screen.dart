import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/channel.dart';
import '../models/epg_entry.dart';
import '../services/xtream_service.dart';
import '../services/history_service.dart';
import '../services/parental_service.dart';
import '../services/epg_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'player_screen.dart';
import 'epg_search_screen.dart';
import '../widgets/reminder_button.dart';

class LiveScreen extends StatefulWidget {
  final XtreamService service;
  const LiveScreen({super.key, required this.service});
  @override State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Category> _categories = [];
  List<Channel> _channels = [];
  int _selectedCatIndex = 0;
  bool _loadingCats = true, _loadingChannels = false;
  final _catFocusNodes = <FocusNode>[];
  final _channelFocusNodes = <FocusNode>[];

  // ── Búsqueda de canales ──────────────────────────────────────────────────
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  List<Channel> get _visibleChannels => _searchQuery.isEmpty
      ? _channels
      : _channels.where((c) =>
          c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  static final _virtualCats = [
    Category(id: HistoryService.recentCatId, name: 'Recientes'),
    Category(id: HistoryService.favCatId,    name: 'Favoritos'),
  ];

  @override void initState() { super.initState(); _loadCategories(); }

  @override void dispose() {
    for (final n in [..._catFocusNodes, ..._channelFocusNodes]) n.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final results = await Future.wait([
      widget.service.getLiveCategories(),
      ParentalService.getBlocked('live'),
    ]);
    if (!mounted) return;
    final cats    = results[0] as List<Category>;
    final blocked = results[1] as Set<String>;
    final visible = cats.where((c) => !blocked.contains(c.id)).toList();
    final all = [..._virtualCats, ...visible];
    _catFocusNodes.addAll(List.generate(all.length, (_) => FocusNode()));
    setState(() { _categories = all; _loadingCats = false; });
    if (all.isNotEmpty) _selectCategory(all[0], 0);
  }

  Future<void> _selectCategory(Category cat, int index) async {
    _searchCtrl.clear();
    setState(() { _selectedCatIndex = index; _loadingChannels = true; _channels = []; _searchQuery = ''; });
    for (final n in _channelFocusNodes) n.dispose();
    _channelFocusNodes.clear();

    List<Channel> ch;
    if (cat.id == HistoryService.recentCatId) {
      final data = await HistoryService.getRecent(HistoryService.live);
      ch = data.map((m) => Channel(id: m['id']!, name: m['name']!, streamType: 'live',
        streamIcon: m['icon'] ?? '', categoryId: '', epgChannelId: '')).toList();
    } else if (cat.id == HistoryService.favCatId) {
      final data = await HistoryService.getFavorites(HistoryService.live);
      ch = data.map((m) => Channel(id: m['id']!, name: m['name']!, streamType: 'live',
        streamIcon: m['icon'] ?? '', categoryId: '', epgChannelId: '')).toList();
    } else {
      ch = await widget.service.getLiveStreams(categoryId: cat.id);
    }
    if (!mounted) return;
    _channelFocusNodes.addAll(List.generate(ch.length, (_) => FocusNode()));
    setState(() { _channels = ch; _loadingChannels = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: _liveAppBar(context),
    body: Column(children: [
      // ── Barra de búsqueda de canales ─────────────────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: _showSearch
          ? _buildSearchBar(context, AppColors.celeste)
          : const SizedBox.shrink(),
      ),
      // ── Contenido principal ─────────────────────────────────────────
      Expanded(child: Row(children: [
        SizedBox(width: R.catPanelW(context),
          child: _loadingCats
            ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final isVirtual = i < _virtualCats.length;
                  return CatTile(
                    name: _categories[i].name,
                    isSelected: _selectedCatIndex == i,
                    accentColor: isVirtual ? Colors.amber : AppColors.celeste,
                    focusNode: _catFocusNodes[i],
                    autofocus: i == 0,
                    onSelect: () => _selectCategory(_categories[i], i),
                  );
                })),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _loadingChannels
          ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
          : _visibleChannels.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_searchQuery.isNotEmpty ? Icons.search_off : Icons.tv_off,
                  color: Colors.white24, size: 40),
                const SizedBox(height: 10),
                Text(_searchQuery.isNotEmpty
                  ? 'Sin resultados para "$_searchQuery"'
                  : (_selectedCatIndex < _virtualCats.length
                    ? 'Aún no hay nada aquí' : 'Sin canales'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]))
            : ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: R.padding(context)),
                itemCount: _visibleChannels.length,
                itemBuilder: (_, i) {
                  final ch = _visibleChannels[i];
                  return _ChannelTile(
                    channel: ch, service: widget.service,
                    channels: _channels,
                    channelIndex: _channels.indexOf(ch),
                    focusNode: i < _channelFocusNodes.length ? _channelFocusNodes[i] : FocusNode(),
                    autofocus: i == 0,
                    onFavChanged: () => _selectCategory(_categories[_selectedCatIndex], _selectedCatIndex),
                  );
                })),
      ])),
    ]),
  );

  PreferredSizeWidget _liveAppBar(BuildContext context) => AppBar(
    backgroundColor: const Color(0xFF080B14),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
      focusColor: AppColors.celeste.withOpacity(0.2),
      onPressed: () => Navigator.pop(context),
    ),
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.live_tv, color: AppColors.celeste, size: 20),
      const SizedBox(width: 8),
      Text('En Vivo', style: TextStyle(color: Colors.white,
        fontSize: R.fs(context, 17), fontWeight: FontWeight.w600)),
    ]),
    actions: [
      // Búsqueda de canales (inline)
      IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Icon(
            _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
            key: ValueKey(_showSearch),
            color: _showSearch ? AppColors.celeste : Colors.white70, size: 22)),
        tooltip: 'Buscar canal',
        onPressed: () {
          setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) { _searchCtrl.clear(); _searchQuery = ''; }
          });
        },
      ),
      // Búsqueda en EPG
      IconButton(
        icon: const Icon(Icons.manage_search_rounded, color: Colors.white70, size: 22),
        tooltip: 'Buscar en EPG',
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => EpgSearchScreen(service: widget.service, channels: _channels))),
      ),
      // Ajuste de zona horaria
      IconButton(
        icon: const Icon(Icons.schedule_rounded, color: Colors.white70, size: 22),
        tooltip: 'Zona horaria EPG',
        onPressed: () => _showTimezoneSheet(context),
      ),
    ],
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1),
      child: Divider(color: Colors.white10, height: 1)),
  );

  // ── Barra de búsqueda inline reutilizable ────────────────────────────────
  Widget _buildSearchBar(BuildContext ctx, Color accentColor) {
    final p = R.padding(ctx);
    return Container(
      color: const Color(0xFF080B14),
      padding: EdgeInsets.fromLTRB(p + 6, 8, p + 6, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(0.35))),
        child: Row(children: [
          Padding(
            padding: EdgeInsets.only(left: p),
            child: Icon(Icons.search, color: accentColor, size: 18)),
          Expanded(child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Buscar...',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
            onChanged: (q) => setState(() => _searchQuery = q),
          )),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38, size: 16),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              }),
        ]),
      ),
    );
  }

  void _showTimezoneSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EpgTimezoneSheet(
        currentOffset: EpgSettingsService.offsetHours,
        onChanged: (offset) async {
          await EpgSettingsService.setOffset(offset);
          if (!mounted) return;
          // Recargar EPG de todos los canales visibles
          setState(() {});
          for (final n in _channelFocusNodes) n.dispose();
          _channelFocusNodes.clear();
          if (_categories.isNotEmpty) {
            _selectCategory(_categories[_selectedCatIndex], _selectedCatIndex);
          }
        },
      ),
    );
  }

  Widget _emptyState(bool isVirtual) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(isVirtual ? Icons.inbox_outlined : Icons.tv_off, color: Colors.white24, size: 48),
    const SizedBox(height: 12),
    Text(isVirtual ? 'Aún no hay nada aquí' : 'Sin canales',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
  ]));
}

// ─── Shared AppBar ────────────────────────────────────────────────────────────
PreferredSizeWidget sectionAppBar(
  BuildContext ctx,
  String title,
  IconData icon,
  Color color, {
  List<Widget>? actions,
}) =>
  AppBar(
    backgroundColor: const Color(0xFF080B14),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
      focusColor: AppColors.celeste.withOpacity(0.2),
      onPressed: () => Navigator.pop(ctx),
    ),
    title: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 20), const SizedBox(width: 8),
      Text(title, style: TextStyle(color: Colors.white,
        fontSize: R.fs(ctx, 17), fontWeight: FontWeight.w600)),
    ]),
    actions: actions,
    bottom: const PreferredSize(preferredSize: Size.fromHeight(1),
      child: Divider(color: Colors.white10, height: 1)),
  );

// ─── Shared CatTile (público para reutilizar) ─────────────────────────────────
class CatTile extends StatefulWidget {
  final String name;
  final bool isSelected;
  final Color accentColor;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onSelect;
  const CatTile({required this.name, required this.isSelected, required this.accentColor,
    required this.focusNode, required this.autofocus, required this.onSelect});
  @override State<CatTile> createState() => CatTileState();
}
class CatTileState extends State<CatTile> {
  bool _focused = false;
  @override void initState() {
    super.initState();
    widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
  }
  @override Widget build(BuildContext context) {
    final active = widget.isSelected || _focused;
    final isPhone = R.isPhone(context);
    return InkWell(
      focusNode: widget.focusNode, autofocus: widget.autofocus,
      focusColor: Colors.transparent, onTap: widget.onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.symmetric(horizontal: isPhone ? 4 : 6, vertical: 3),
        padding: EdgeInsets.symmetric(horizontal: isPhone ? 8 : 12, vertical: isPhone ? 9 : 11),
        decoration: BoxDecoration(
          gradient: widget.isSelected ? AppColors.buttonGradient : null,
          color: widget.isSelected ? null : (_focused ? Colors.white12 : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _focused ? widget.accentColor : Colors.transparent, width: 2),
        ),
        child: Text(widget.name, style: TextStyle(
          color: active ? Colors.white : AppColors.textSecondary,
          fontSize: R.fs(context, 12),
          fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ─── Channel Tile ─────────────────────────────────────────────────────────────
class _ChannelTile extends StatefulWidget {
  final Channel channel;
  final XtreamService service;
  final List<Channel> channels;
  final int channelIndex;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onFavChanged;
  const _ChannelTile({required this.channel, required this.service,
    required this.channels, required this.channelIndex,
    required this.focusNode, this.autofocus = false, required this.onFavChanged});
  @override State<_ChannelTile> createState() => _ChannelTileState();
}
class _ChannelTileState extends State<_ChannelTile> {
  bool _focused = false, _isFav = false;
  List<EpgEntry> _epg = [];
  bool _epgLoaded = false;
  Timer? _epgRefreshTimer;

  @override void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
    _loadFav();
    _loadEpg();
  }

  Future<void> _loadFav() async {
    final fav = await HistoryService.isFavorite(HistoryService.live, widget.channel.id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _loadEpg() async {
    final entries = await widget.service.getShortEpg(widget.channel.id);
    if (mounted) setState(() { _epg = entries; _epgLoaded = true; });
    _scheduleEpgRefresh();
  }

  /// Programa un timer para refrescar EPG justo cuando termine el programa actual
  void _scheduleEpgRefresh() {
    _epgRefreshTimer?.cancel();
    final cur = _current;
    if (cur == null) return;
    final remaining = cur.end.difference(DateTime.now());
    // Si ya terminó o termina en menos de 5s, refrescar ahora
    final delay = remaining.isNegative ? Duration.zero
        : remaining + const Duration(seconds: 5);
    _epgRefreshTimer = Timer(delay, () async {
      if (!mounted) return;
      XtreamService.clearEpgCacheForChannel(widget.channel.id);
      await _loadEpg();
    });
  }

  Future<void> _toggleFav() async {
    final newState = await HistoryService.toggleFavorite(
      HistoryService.live, widget.channel.id,
      {'id': widget.channel.id, 'name': widget.channel.name, 'icon': widget.channel.streamIcon});
    if (mounted) { setState(() => _isFav = newState); widget.onFavChanged(); }
  }

  Future<void> _play() async {
    await HistoryService.addRecent(HistoryService.live,
      {'id': widget.channel.id, 'name': widget.channel.name, 'icon': widget.channel.streamIcon});
    if (!mounted) return;
    // Pasar programa actual al player si está disponible
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
      title: widget.channel.name,
      streamUrl: widget.service.liveStreamUrl(widget.channel.id),
      epgTitle: _current?.title,
      channels: widget.channels,
      channelIndex: widget.channelIndex,
      service: widget.service,
    )));
  }

  // Programa actual (si la lista no está vacía y el primero no ha terminado)
  EpgEntry? get _current {
    if (_epg.isEmpty) return null;
    final now = DateTime.now();
    return _epg.firstWhere(
      (e) => e.start.isBefore(now) && e.end.isAfter(now),
      orElse: () => _epg.first,
    );
  }

  EpgEntry? get _next {
    if (_epg.length < 2) return null;
    final c = _current;
    if (c == null) return null;
    final idx = _epg.indexOf(c);
    return idx + 1 < _epg.length ? _epg[idx + 1] : null;
  }

  @override Widget build(BuildContext context) {
    final isPhone = R.isPhone(context);
    final sz = isPhone ? 36.0 : 48.0;
    final cur = _current;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      decoration: BoxDecoration(
        color: _focused ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
      ),
      // ── Row externo: canal (tappable) + corazón (sibling, no nested) ──
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: InkWell(
            focusNode: widget.focusNode, autofocus: widget.autofocus,
            focusColor: Colors.transparent, onTap: _play,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 8 : 12,
                vertical: isPhone ? 7 : 9),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Logo + nombre + badge ─────────────────────────────
                Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: widget.channel.streamIcon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.channel.streamIcon,
                          width: sz, height: sz * 0.75,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => _icon(sz),
                          errorWidget: (_, __, ___) => _icon(sz))
                      : _icon(sz)),
                  SizedBox(width: isPhone ? 8 : 12),
                  Expanded(child: Text(widget.channel.name,
                    style: TextStyle(
                      color: _focused ? Colors.white : AppColors.textPrimary,
                      fontSize: R.fs(context, 14),
                      fontWeight: _focused ? FontWeight.w600 : FontWeight.normal),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (!isPhone)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.red.withOpacity(0.5))),
                      child: const Text('● VIVO',
                        style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold))),
                ]),

                // ── EPG: programa actual + barra ──────────────────────
                if (_epgLoaded && cur != null) ...[
                  const SizedBox(height: 5),
                  Padding(
                    padding: EdgeInsets.only(left: sz + (isPhone ? 8 : 12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(cur.title,
                          style: TextStyle(
                            color: _focused ? AppColors.celeste : Colors.white54,
                            fontSize: R.fs(context, 11),
                            fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        Text(cur.timeRange,
                          style: const TextStyle(color: Colors.white30, fontSize: 10)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: cur.progress,
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _focused ? AppColors.celeste : AppColors.celeste.withOpacity(0.5)),
                        ),
                      ),
                    ]),
                  ),
                ] else if (!_epgLoaded) ...[
                  Padding(
                    padding: EdgeInsets.only(left: sz + (isPhone ? 8 : 12), top: 4),
                    child: const SizedBox(
                      width: 80, height: 3,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white12))),
                  ),
                ],
              ]),
            ),
          ),
        ),

        // ── Recordatorio próximo programa ─────────────────────────────
        if (_next != null && _next!.start.isAfter(DateTime.now()))
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 4 : 6,
              vertical: isPhone ? 10 : 14),
            child: ReminderBell(
              channel: widget.channel,
              program: _next!,
              size: 18,
            )),

        // ── Corazón: FUERA del InkWell para evitar conflicto de gestos ──
        GestureDetector(
          onTap: _toggleFav,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 10 : 12,
              vertical: isPhone ? 10 : 14),
            child: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : Colors.white30,
              size: 20)),
        ),
      ]),
    );
  }

  @override void dispose() {
    _epgRefreshTimer?.cancel();
    super.dispose();
  }

  Widget _icon(double sz) => Container(
    width: sz, height: sz * 0.75, color: AppColors.card,
    child: const Icon(Icons.tv, color: AppColors.celeste, size: 16));
}

// ─── Panel de zona horaria EPG ────────────────────────────────────────────────
class _EpgTimezoneSheet extends StatefulWidget {
  final int currentOffset;
  final Future<void> Function(int) onChanged;
  const _EpgTimezoneSheet({required this.currentOffset, required this.onChanged});
  @override State<_EpgTimezoneSheet> createState() => _EpgTimezoneSheetState();
}

class _EpgTimezoneSheetState extends State<_EpgTimezoneSheet> {
  late int _offset;
  bool _saving = false;

  @override void initState() { super.initState(); _offset = widget.currentOffset; }

  String get _label {
    if (_offset == 0) return 'Sin ajuste (servidor)';
    return _offset > 0 ? '+$_offset horas' : '$_offset horas';
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1020),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(margin: const EdgeInsets.only(top: 10, bottom: 2),
        width: 36, height: 4,
        decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(2))),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(Icons.schedule_rounded, color: AppColors.celeste, size: 20),
          SizedBox(width: 10),
          Text('Zona horaria EPG', style: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
      const Divider(color: Colors.white10, height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(children: [
          Text(_label, style: const TextStyle(
            color: AppColors.celeste, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Ajusta si los horarios del EPG no coinciden con tu zona horaria',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.celeste,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppColors.celeste,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: _offset.toDouble(),
              min: -12, max: 12,
              divisions: 24,
              onChanged: (v) => setState(() => _offset = v.round()),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('-12h', style: TextStyle(color: Colors.white30, fontSize: 11)),
            const Text('0', style: TextStyle(color: Colors.white30, fontSize: 11)),
            const Text('+12h', style: TextStyle(color: Colors.white30, fontSize: 11)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white38,
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Cancelar'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                await widget.onChanged(_offset);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.celeste,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Aplicar'))),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
    ]),
  );
}
