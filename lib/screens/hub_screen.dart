import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'search_screen.dart';
import '../services/xtream_service.dart';

class HubScreen extends StatefulWidget {
  final Map<String, String> credentials;
  const HubScreen({super.key, required this.credentials});
  @override State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late XtreamService _service;
  int _focused = 0;
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());

  String get _expDate {
    final raw = widget.credentials['exp_date'] ?? '';
    if (raw.isEmpty) return 'N/D';
    try {
      final ts = int.parse(raw);
      final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
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
  void dispose() {
    for (final n in _focusNodes) n.dispose();
    super.dispose();
  }

  void _open(int index) {
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

  void _showInfo() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0D1020),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/logo.png', width: 80,
          errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: AppColors.celeste, size: 48)),
        const SizedBox(height: 16),
        const Text('TODO EN UNO TV', style: TextStyle(color: Colors.white,
          fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 20),
        _infoRow(Icons.calendar_today, 'Vencimiento', _expDate),
        const SizedBox(height: 10),
        _infoRow(Icons.person, 'Usuario', widget.credentials['username'] ?? ''),
        const SizedBox(height: 10),
        _infoRow(Icons.language, 'Sitio web', 'todoenunotv.com'),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar', style: TextStyle(color: AppColors.celeste))),
      ]),
    ));
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: AppColors.celeste, size: 18),
    const SizedBox(width: 10),
    Text('$label: ', style: const TextStyle(color: Colors.white60, fontSize: 13)),
    Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13,
      fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
  ]);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1530), Color(0xFF0A0E1A)]),
        ),
        child: SafeArea(child: Column(children: [
          // TOP BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(children: [
              Image.asset('assets/images/logo.png', height: 40,
                errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: AppColors.celeste, size: 36)),
              const SizedBox(width: 12),
              const Text('TODO EN UNO TV',
                style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const Spacer(),
              // Info button
              _TopButton(
                focusNode: _focusNodes[4],
                icon: Icons.info_outline,
                onTap: _showInfo,
              ),
            ]),
          ),
          const Divider(color: Colors.white10, height: 1),

          // WELCOME
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(
              'Bienvenido, ${widget.credentials['username'] ?? ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
          ),

          // MAIN CARDS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _HeroCard(
                    focusNode: _focusNodes[0],
                    isFocused: _focused == 0,
                    icon: Icons.live_tv,
                    title: 'En Vivo',
                    subtitle: 'Canales en tiempo real',
                    color: const Color(0xFF00C3CC),
                    onTap: () => _open(0),
                  ),
                  const SizedBox(width: 20),
                  _HeroCard(
                    focusNode: _focusNodes[1],
                    isFocused: _focused == 1,
                    icon: Icons.movie_outlined,
                    title: 'Películas',
                    subtitle: 'Catálogo completo',
                    color: const Color(0xFF3372E3),
                    onTap: () => _open(1),
                  ),
                  const SizedBox(width: 20),
                  _HeroCard(
                    focusNode: _focusNodes[2],
                    isFocused: _focused == 2,
                    icon: Icons.tv,
                    title: 'Series',
                    subtitle: 'Temporadas y episodios',
                    color: const Color(0xFF7426EF),
                    onTap: () => _open(2),
                  ),
                  const SizedBox(width: 20),
                  _HeroCard(
                    focusNode: _focusNodes[3],
                    isFocused: _focused == 3,
                    icon: Icons.search,
                    title: 'Buscar',
                    subtitle: 'Todo el contenido',
                    color: const Color(0xFF5DE0E6),
                    onTap: () => _open(3),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
            child: Row(children: [
              const Icon(Icons.language, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              const Text('todoenunotv.com', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const Spacer(),
              const Icon(Icons.calendar_today, color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text('Vence: $_expDate', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
        ])),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final FocusNode focusNode;
  final bool isFocused;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HeroCard({required this.focusNode, required this.isFocused, required this.icon,
    required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        focusNode: focusNode,
        onTap: onTap,
        focusColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(isFocused ? 1.06 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isFocused ? color.withOpacity(0.25) : const Color(0xFF0D1020),
            border: Border.all(
              color: isFocused ? color : Colors.white12,
              width: isFocused ? 3 : 1,
            ),
            boxShadow: isFocused ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)] : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: isFocused ? color : Colors.white38,
                size: isFocused ? 56 : 48),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(
                color: isFocused ? Colors.white : Colors.white70,
                fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(
                color: isFocused ? Colors.white60 : Colors.white30,
                fontSize: 12),
                textAlign: TextAlign.center),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onTap;
  const _TopButton({required this.focusNode, required this.icon, required this.onTap});
  @override State<_TopButton> createState() => _TopButtonState();
}
class _TopButtonState extends State<_TopButton> {
  bool _focused = false;
  @override
  void initState() {
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _focused ? AppColors.celeste.withOpacity(0.2) : Colors.white10,
        border: Border.all(color: _focused ? AppColors.celeste : Colors.transparent, width: 2),
      ),
      child: Icon(widget.icon, color: _focused ? AppColors.celeste : Colors.white60, size: 22),
    ),
  );
}
