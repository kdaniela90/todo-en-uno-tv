import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'search_screen.dart';
import '../services/xtream_service.dart';
import '../services/parental_service.dart';
import '../services/storage_service.dart';
import '../widgets/animated_remote.dart';
import 'parental_screen.dart';

class HubScreen extends StatefulWidget {
  final Map<String, String> credentials;
  const HubScreen({super.key, required this.credentials});
  @override State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late XtreamService _service;
  int _focused = 0;
  final List<FocusNode> _focusNodes = List.generate(7, (_) => FocusNode());

  String get _expDate {
    final raw = widget.credentials['exp_date'] ?? '';
    if (raw.isEmpty) return 'N/D';
    try {
      final ts = int.parse(raw);
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return raw; }
  }

  @override
  void initState() {
    super.initState();
    _service = XtreamService(
      server: widget.credentials['server']!,
      username: widget.credentials['username']!,
      password: widget.credentials['password']!,
    );
    for (int i = 0; i < _focusNodes.length; i++) {
      final idx = i;
      _focusNodes[idx].addListener(() {
        if (_focusNodes[idx].hasFocus && mounted) setState(() => _focused = idx);
      });
    }
  }

  @override
  void dispose() { for (final n in _focusNodes) n.dispose(); super.dispose(); }

  void _open(int index) async {
    if (index == 4) { await _openParental(); return; }
    final screens = [
      LiveScreen(service: _service),
      MoviesScreen(service: _service),
      SeriesScreen(service: _service),
      SearchScreen(service: _service),
    ];
    if (index < screens.length) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screens[index]));
    }
  }

  Future<void> _openParental() async {
    final hasPinAlready = await ParentalService.hasPin();

    if (!hasPinAlready) {
      // First time: create PIN
      if (!mounted) return;
      final pin1 = await showPinDialog(context, title: 'Crea tu PIN de 4 dígitos');
      if (pin1 == null || pin1.length < 4) return;
      if (!mounted) return;
      final pin2 = await showPinDialog(context, title: 'Confirma tu PIN');
      if (pin2 == null) return;
      if (pin1 != pin2) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los PINs no coinciden'), backgroundColor: Colors.red));
        return;
      }
      await ParentalService.setPin(pin1);
    } else {
      // Verify existing PIN
      if (!mounted) return;
      final entered = await showPinDialog(context, title: 'Control Parental\nIngresa tu PIN');
      if (entered == null) return;
      final ok = await ParentalService.checkPin(entered);
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorrecto'), backgroundColor: Colors.red,
            duration: Duration(seconds: 2)));
        return;
      }
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ParentalScreen(service: _service)));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          '¿Deseas cerrar sesión y cambiar de playlist?',
          style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await StorageService.clearCredentials();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showInfo() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0D1020),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedRemote(width: 32, height: 64),
        const SizedBox(height: 14),
        const Text('TODO EN UNO TV',
          style: TextStyle(color: Colors.white, fontSize: 16,
            fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 18),
        _infoRow(Icons.calendar_today, 'Vencimiento', _expDate),
        const SizedBox(height: 10),
        _infoRow(Icons.person, 'Usuario', widget.credentials['username'] ?? ''),
        const SizedBox(height: 10),
        _infoRow(Icons.dns_rounded, 'Servidor', widget.credentials['server'] ?? ''),
        const SizedBox(height: 10),
        _infoRow(Icons.language, 'Sitio web', 'todoenunotv.com'),
        const SizedBox(height: 18),
        const Divider(color: Colors.white10),
        const SizedBox(height: 10),

        // ── Botón de Refresh ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Actualizar contenido'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.celeste,
              side: BorderSide(color: AppColors.celeste.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: () {
              XtreamService.clearEpgCache();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text('Caché limpiado. El contenido se cargará nuevo.'),
                  ]),
                  backgroundColor: AppColors.celeste.withOpacity(0.85),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 3),
                ));
            },
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar', style: TextStyle(color: Colors.white38))),
      ]),
    ));
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: AppColors.celeste, size: 16),
    const SizedBox(width: 8),
    Text('$label: ', style: const TextStyle(color: Colors.white60, fontSize: 13)),
    Expanded(child: Text(value, style: const TextStyle(color: Colors.white,
      fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
  ]);

  static const _cards = [
    (Icons.live_tv,         'En Vivo',    'Canales en tiempo real',  Color(0xFF00C3CC)),
    (Icons.movie_outlined,  'Películas',  'Catálogo completo',        Color(0xFF3372E3)),
    (Icons.tv,              'Series',     'Temporadas y episodios',   Color(0xFF7426EF)),
    (Icons.search,          'Buscar',     'Todo el contenido',        Color(0xFF5DE0E6)),
    (Icons.shield_outlined, 'Parental',   'Control de contenido',     Color(0xFFE86C2A)),
  ];

  @override
  Widget build(BuildContext context) {
    final isPhone = R.isPhone(context);
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF060C1B), Color(0xFF0A1128), Color(0xFF060C1B)])),
        child: SafeArea(child: Column(children: [
          // TOP BAR
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isPhone ? 14 : 24, vertical: isPhone ? 10 : 14),
            child: Row(children: [
              AnimatedRemote(width: isPhone ? 18 : 24, height: isPhone ? 36 : 48),
              SizedBox(width: isPhone ? 8 : 12),
              Text('TODO EN UNO TV',
                style: TextStyle(color: Colors.white, fontSize: isPhone ? 14 : 20,
                  fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const Spacer(),
              _TopButton(focusNode: _focusNodes[5], icon: Icons.info_outline, onTap: _showInfo),
              const SizedBox(width: 6),
              _TopButton(focusNode: _focusNodes[6], icon: Icons.logout, onTap: _logout),
            ]),
          ),
          const Divider(color: Colors.white10, height: 1),

          Padding(
            padding: EdgeInsets.only(top: isPhone ? 10 : 18, bottom: 4),
            child: Text('Bienvenido, ${widget.credentials['username'] ?? ''}',
              style: TextStyle(color: Colors.white54, fontSize: isPhone ? 12 : 14)),
          ),

          // CARDS — fila en TV/tablet, grid 2×2 en teléfono
          Expanded(
            child: isPhone ? _phoneGrid(context) : _tvRow(context),
          ),

          // BOTTOM BAR
          Container(
            padding: EdgeInsets.symmetric(horizontal: isPhone ? 14 : 24, vertical: isPhone ? 8 : 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
            child: Row(children: [
              const Icon(Icons.language, color: Colors.white38, size: 12),
              const SizedBox(width: 5),
              const Text('todoenunotv.com', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              const Icon(Icons.calendar_today, color: Colors.white38, size: 12),
              const SizedBox(width: 5),
              Text('Vence: $_expDate', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
        ])),
      ),
    );
  }

  // TV / Tablet: 4 tarjetas en fila
  Widget _tvRow(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_cards.length, (i) {
        final c = _cards[i];
        return Expanded(child: Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
          child: _HeroCard(
            focusNode: _focusNodes[i], isFocused: _focused == i,
            icon: c.$1, title: c.$2, subtitle: c.$3, color: c.$4,
            onTap: () => _open(i),
          ),
        ));
      }),
    ),
  );

  // Teléfono: grid 2×N scrollable
  Widget _phoneGrid(BuildContext context) => GridView.count(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    crossAxisCount: 2,
    childAspectRatio: 2.4,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    children: List.generate(_cards.length, (i) {
      final c = _cards[i];
      return _HeroCard(
        focusNode: _focusNodes[i], isFocused: _focused == i,
        icon: c.$1, title: c.$2, subtitle: c.$3, color: c.$4,
        compact: true,
        onTap: () => _open(i),
      );
    }),
  );
}

// ─── Hero Card ────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final FocusNode focusNode;
  final bool isFocused;
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _HeroCard({required this.focusNode, required this.isFocused, required this.icon,
    required this.title, required this.subtitle, required this.color,
    required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) => InkWell(
    focusNode: focusNode,
    onTap: onTap,
    focusColor: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isFocused ? color.withOpacity(0.22) : const Color(0xFF0D1020),
        border: Border.all(color: isFocused ? color : Colors.white12, width: isFocused ? 2.5 : 1),
        boxShadow: isFocused ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 18, spreadRadius: 1)] : [],
      ),
      child: compact
        // Teléfono: icono + texto en fila
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(icon, color: isFocused ? color : Colors.white38, size: isFocused ? 32 : 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: TextStyle(color: isFocused ? Colors.white : Colors.white70,
                  fontSize: 14, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: isFocused ? Colors.white54 : Colors.white30,
                  fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )
        // TV/tablet: icono centrado arriba + texto
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: isFocused ? color : Colors.white38, size: isFocused ? 52 : 44),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(color: isFocused ? Colors.white : Colors.white70,
                fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 5),
              Text(subtitle, style: TextStyle(color: isFocused ? Colors.white54 : Colors.white30,
                fontSize: 11), textAlign: TextAlign.center),
            ]),
          ),
    ),
  );
}

// ─── Top Button ───────────────────────────────────────────────────────────────
class _TopButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onTap;
  const _TopButton({required this.focusNode, required this.icon, required this.onTap});
  @override State<_TopButton> createState() => _TopButtonState();
}
class _TopButtonState extends State<_TopButton> {
  bool _focused = false;
  @override void initState() {
    super.initState();
    widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
  }
  @override
  Widget build(BuildContext context) => InkWell(
    focusNode: widget.focusNode,
    onTap: widget.onTap,
    focusColor: Colors.transparent,
    borderRadius: BorderRadius.circular(24),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.all(R.isPhone(context) ? 7 : 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _focused ? AppColors.celeste.withOpacity(0.2) : Colors.white10,
        border: Border.all(color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
      ),
      child: Icon(widget.icon, color: _focused ? AppColors.celeste : Colors.white60,
        size: R.isPhone(context) ? 18 : 22),
    ),
  );
}
