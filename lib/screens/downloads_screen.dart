import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadedItem> _items = [];
  bool _loading = true;
  String _totalSize = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await DownloadService.getDownloads();
    final size = await DownloadService.totalSizeLabel();
    if (!mounted) return;
    setState(() { _items = items; _totalSize = size; _loading = false; });
  }

  Future<void> _delete(DownloadedItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar descarga',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Eliminar "${item.name}"? Se borrará el archivo del dispositivo.',
          style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    await DownloadService.deleteDownload(item.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Descarga eliminada'),
        ]),
        backgroundColor: Colors.red.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _play(DownloadedItem item) {
    final file = File(item.filePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Archivo no encontrado. Puede haberse eliminado.'),
        backgroundColor: Colors.red.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
      _load(); // Refresca por si el archivo ya no existe
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
      title: item.name,
      streamUrl: 'file://${item.filePath}',
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = R.isPhone(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // AppBar
          Container(
            color: const Color(0xFF080B14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('Descargas',
                    style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold))),
                  if (_totalSize.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(_totalSize,
                        style: const TextStyle(color: Colors.white38, fontSize: 12))),
                ]),
              ),
              const Divider(color: Colors.white10, height: 1),
            ]),
          ),

          // Contenido
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.celeste))
              : _items.isEmpty
                ? _emptyState()
                : isPhone
                  ? _listView()
                  : _gridView(),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.download_rounded, size: 64, color: Colors.white12),
      const SizedBox(height: 16),
      const Text('Sin descargas',
        style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Descarga películas y episodios\ndesde su pantalla de detalle',
        style: TextStyle(color: Colors.white24, fontSize: 13),
        textAlign: TextAlign.center),
    ]),
  );

  Widget _listView() => ListView.builder(
    padding: const EdgeInsets.all(12),
    itemCount: _items.length,
    itemBuilder: (_, i) => _DownloadTile(
      item: _items[i],
      onPlay: () => _play(_items[i]),
      onDelete: () => _delete(_items[i]),
    ),
  );

  Widget _gridView() => GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.65,
    ),
    itemCount: _items.length,
    itemBuilder: (_, i) => _DownloadCard(
      item: _items[i],
      onPlay: () => _play(_items[i]),
      onDelete: () => _delete(_items[i]),
    ),
  );
}

// ─── Tile (modo lista / teléfono) ─────────────────────────────────────────────
class _DownloadTile extends StatelessWidget {
  final DownloadedItem item;
  final VoidCallback onPlay, onDelete;
  const _DownloadTile({required this.item, required this.onPlay, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1020),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white10)),
    child: Row(children: [
      // Poster
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.poster?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: item.poster!, width: 60, height: 80, fit: BoxFit.cover,
              placeholder: (_, __) => _posterBox(),
              errorWidget: (_, __, ___) => _posterBox())
          : _posterBox(),
      ),
      const SizedBox(width: 12),
      // Info
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name,
          style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w600),
          maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(children: [
          _TypeBadge(type: item.type),
          if (item.sizeLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(item.sizeLabel,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ]),
      ])),
      // Botones
      IconButton(
        icon: const Icon(Icons.play_circle_rounded,
          color: AppColors.celeste, size: 36),
        onPressed: onPlay),
      IconButton(
        icon: const Icon(Icons.delete_outline,
          color: Colors.white24, size: 22),
        onPressed: onDelete),
    ]),
  );

  Widget _posterBox() => Container(
    width: 60, height: 80, color: AppColors.card,
    child: const Icon(Icons.movie, color: AppColors.azul, size: 28));
}

// ─── Card (modo grid / TV) ────────────────────────────────────────────────────
class _DownloadCard extends StatelessWidget {
  final DownloadedItem item;
  final VoidCallback onPlay, onDelete;
  const _DownloadCard({required this.item, required this.onPlay, required this.onDelete});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPlay,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1020),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10)),
      child: Column(children: [
        // Poster
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: item.poster?.isNotEmpty == true
              ? CachedNetworkImage(
                  imageUrl: item.poster!,
                  width: double.infinity, fit: BoxFit.cover,
                  placeholder: (_, __) => _posterBox(),
                  errorWidget: (_, __, ___) => _posterBox())
              : _posterBox(),
          ),
        ),
        // Info + botones
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                style: const TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                _TypeBadge(type: item.type),
                if (item.sizeLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(item.sizeLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 9)),
                ],
              ]),
            ])),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.delete_outline,
                color: Colors.white24, size: 18),
              onPressed: onDelete),
          ]),
        ),
      ]),
    ),
  );

  Widget _posterBox() => Container(
    color: AppColors.card,
    child: const Center(child: Icon(Icons.movie, color: AppColors.azul, size: 36)));
}

// ─── Badge tipo (Película / Serie) ───────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final isSeries = type == 'series';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (isSeries ? AppColors.morado : AppColors.azul).withOpacity(0.25),
        borderRadius: BorderRadius.circular(4)),
      child: Text(isSeries ? 'Serie' : 'Película',
        style: TextStyle(
          color: isSeries ? AppColors.morado : AppColors.celeste,
          fontSize: 9, fontWeight: FontWeight.bold)));
  }
}
