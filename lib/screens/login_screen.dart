import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  static const String _server = 'http://allinonestream.fans:8080';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final service = XtreamService(
      server: _server,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );

    final result = await service.login();
    if (!mounted) return;

    if (result != null && result['user_info'] != null) {
      await StorageService.saveCredentials(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        server: _server,
      );
      Navigator.pushReplacementNamed(context, '/home', arguments: {
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'server': _server,
      });
    } else {
      setState(() {
        _error = 'Usuario o contraseña incorrectos.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = MediaQuery.of(context).size.width > 600;
    final formWidth = isTV ? 420.0 : double.infinity;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: SizedBox(
              width: formWidth,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: isTV ? 160 : 120,
                      errorBuilder: (_, __, ___) => const Icon(Icons.tv, size: 80, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('TODO EN UNO TV',
                      style: TextStyle(color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    const Text('Inicia sesión con tus credenciales',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 32),
                    _buildField(
                      controller: _userCtrl,
                      label: 'Usuario',
                      icon: Icons.person_rounded,
                      autofocus: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu usuario' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _passCtrl,
                      label: 'Contraseña',
                      icon: Icons.lock_rounded,
                      obscure: _obscurePass,
                      suffix: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.5)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5DE0E6), Color(0xFF004AAD)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                            ? const SizedBox(width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('INICIAR SESIÓN',
                                style: TextStyle(color: Colors.white, fontSize: 16,
                                  fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('© 2026 Todo en Uno TV',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool autofocus = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autofocus: autofocus,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF5DE0E6)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF5DE0E6), width: 2.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24, width: 1.5)),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
      ),
      validator: validator,
    );
  }
}
