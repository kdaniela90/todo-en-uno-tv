import 'package:flutter/material.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, String> credentials;
  const HomeScreen({super.key, required this.credentials});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late XtreamService _service;

  final _navItems = const [
    _NavItem(icon: Icons.live_tv, label: 'En Vivo'),
    _NavItem(icon: Icons.movie_outlined, label: 'Películas'),
    _NavItem(icon: Icons.settings_outlined, label: 'Ajustes'),
  ];

  @override
  void initState() {
    super.initState();
    _service = XtreamService(
      server: widget.credentials['server']!,
      username: widget.credentials['username']!,
      password: widget.credentials['password']!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      LiveScreen(service: _service),
      MoviesScreen(service: _service),
      SettingsScreen(credentials: widget.credentials),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // LEFT NAV RAIL
          Container(
            width: 72,
            color: const Color(0xFF080B14),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  width: 44,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.tv, color: AppColors.celeste, size: 32),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                // Nav items
                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final active = _currentIndex == i;
                  return _NavRailItem(
                    icon: item.icon,
                    label: item.label,
                    isActive: active,
                    autofocus: i == 0,
                    onTap: () => setState(() => _currentIndex = i),
                  );
                }),
              ],
            ),
          ),
          // Divider
          Container(width: 1, color: Colors.white10),
          // MAIN CONTENT
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavRailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool autofocus;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.autofocus,
    required this.onTap,
  });

  @override
  State<_NavRailItem> createState() => _NavRailItemState();
}

class _NavRailItemState extends State<_NavRailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.isActive || _focused;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.celeste.withOpacity(0.2)
                : (_focused ? Colors.white10 : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? AppColors.celeste : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: highlight ? AppColors.celeste : AppColors.textSecondary,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: highlight ? AppColors.celeste : AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
