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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: AppColors.celeste, size: 28),
            ),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => AppColors.mainGradient.createShader(bounds),
              child: const Text(
                'Todo en Uno TV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.celeste,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/icono-live-tv.png', height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.live_tv)),
              activeIcon: Image.asset('assets/images/icono-live-tv.png', height: 24,
                  color: AppColors.celeste,
                  errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, color: AppColors.celeste)),
              label: 'En Vivo',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/icono-movies.png', height: 24,
                  errorBuilder: (_, __, ___) => const Icon(Icons.movie)),
              activeIcon: Image.asset('assets/images/icono-movies.png', height: 24,
                  color: AppColors.celeste,
                  errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: AppColors.celeste)),
              label: 'Películas',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings, color: AppColors.celeste),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
