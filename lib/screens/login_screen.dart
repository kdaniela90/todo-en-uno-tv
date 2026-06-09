import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_remote.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController();
  final _userCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _serverFocus = FocusNode();
  final _userFocus   = FocusNode();
  final _passFocus   = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static const String _defaultServer = 'http://allinonestream.fans:8080';

  @override
  void initState() {
    super.initState();
    _serverCtrl.text = _defaultServer;
    _userCtrl.text   = '89142158';
    _passCtrl.text   = '0416531';
    // Pre-llenar con credenciales guardadas si existen
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await StorageService.getCredentials();
    if (saved != null && mounted) {
      setState(() {
        _serverCtrl.text = saved['server'] ?? _defaultServer;
        _userCtrl.text   = saved['username'] ?? '';
        _passCtrl.text   = saved['password'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _serverCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    _serverFocus.dispose(); _userFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });

    final server = _serverCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    final service = XtreamService(
      server: server,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim());
    final result = await service.login();
    if (!mounted) return;

    if (result != null && result['user_info'] != null) {
      final expRaw = result['user_info']['exp_date']?.toString() ?? '';
      await StorageService.saveCredentials(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        server: server, expDate: expRaw);
      Navigator.pushReplacementNamed(context, '/hub', arguments: {
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'server': server, 'exp_date': expRaw,
      });
    } else {
      setState(() { _error = 'No se pudo conectar. Verifica la URL del servidor y tus credenciales.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 600;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 32, right: 32, top: 32,
                bottom: keyboardH + 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 420.0 : double.infinity),
                child: Form(
                  key: _formKey,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedRemote(width: wide ? 72 : 54, height: wide ? 144 : 108),
                    const SizedBox(height: 20),
                    const Text('TODO EN UNO TV',
                      style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 6),
                    const Text('Inicia sesión con tus credenciales',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 28),

                    // Servidor
                    _field(
                      ctrl: _serverCtrl, focus: _serverFocus, next: _userFocus,
                      label: 'URL del servidor',
                      icon: Icons.dns_rounded,
                      hint: 'http://servidor:puerto',
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa la URL del servidor';
                        final url = v.trim();
                        if (!url.startsWith('http://') && !url.startsWith('https://')) {
                          return 'La URL debe empezar con http:// o https://';
                        }
                        return null;
                      }),
                    const SizedBox(height: 12),

                    // Usuario
                    _field(
                      ctrl: _userCtrl, focus: _userFocus, next: _passFocus,
                      label: 'Usuario', icon: Icons.person_rounded,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Ingresa tu usuario' : null),
                    const SizedBox(height: 12),

                    // Contraseña
                    _field(
                      ctrl: _passCtrl, focus: _passFocus,
                      label: 'Contraseña', icon: Icons.lock_rounded, obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white54),
                        onPressed: () => setState(() => _obscure = !_obscure)),
                      onSubmit: (_) => _login(),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Ingresa tu contraseña' : null),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withOpacity(0.5))),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Botón principal
                    SizedBox(width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.celeste.withOpacity(0.85),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                        child: _loading
                          ? const SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('INICIAR SESIÓN',
                              style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      )),

                    const SizedBox(height: 20),
                    const Text('© 2026 Todo en Uno TV',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required FocusNode focus,
    FocusNode? next,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmit,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl, focusNode: focus,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    textInputAction: next != null ? TextInputAction.next : TextInputAction.done,
    onFieldSubmitted: onSubmit ?? (_) { if (next != null) next.requestFocus(); },
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.celeste),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.celeste, width: 2.0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24, width: 1.5)),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
    ),
    validator: validator,
  );
}
