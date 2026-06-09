import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_remote.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static const String _server = 'http://allinonestream.fans:8080';

  @override
  void initState() {
    super.initState();
    _userCtrl.text = '89142158';
    _passCtrl.text = '0416531';
  }

  @override
  void dispose() {
    _userCtrl.dispose(); _passCtrl.dispose();
    _userFocus.dispose(); _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });

    final service = XtreamService(
      server: _server,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim());
    final result = await service.login();
    if (!mounted) return;

    if (result != null && result['user_info'] != null) {
      final expRaw = result['user_info']['exp_date']?.toString() ?? '';
      await StorageService.saveCredentials(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        server: _server, expDate: expRaw);
      Navigator.pushReplacementNamed(context, '/hub', arguments: {
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'server': _server, 'exp_date': expRaw,
      });
    } else {
      setState(() {
        _error = 'Usuario o contraseña incorrectos.';
        _loading = false;
      });
    }
  }

  // ── QR local-server login ────────────────────────────────────────────────
  Future<void> _openQrLogin() async {
    String? ip;
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) { ip = addr.address; break; }
        }
        if (ip != null) break;
      }
    } catch (_) {}

    if (ip == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay conexión WiFi activa'), backgroundColor: Colors.red));
      return;
    }

    HttpServer? server;
    try { server = await HttpServer.bind(InternetAddress.anyIPv4, 8765); }
    catch (_) { server = null; }

    if (server == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo iniciar el servidor local')));
      return;
    }

    final url = 'http://$ip:8765';
    bool received = false;

    server.listen((req) async {
      if (received) { req.response.close(); return; }
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      req.response.headers.set('Content-Type', 'text/html; charset=utf-8');

      if (req.method == 'POST') {
        final body = await utf8.decoder.bind(req).join();
        final params = Uri.splitQueryString(body);
        final user = params['username'] ?? '';
        final pass = params['password'] ?? '';
        req.response.write(_successHtml);
        await req.response.close();
        if (user.isNotEmpty && pass.isNotEmpty && mounted) {
          received = true;
          setState(() { _userCtrl.text = user; _passCtrl.text = pass; });
          await server?.close(force: true);
          if (mounted) Navigator.pop(context);
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) _login();
        }
      } else {
        req.response.write(_loginHtml(url));
        await req.response.close();
      }
    });

    if (!mounted) { server.close(force: true); return; }
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _QrDialog(url: url),
    );
    server.close(force: true);
  }

  static String _loginHtml(String url) => '''<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<title>Todo en Uno TV</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#060C1B;font-family:-apple-system,sans-serif;min-height:100vh;
  display:flex;align-items:center;justify-content:center;padding:20px}
.card{background:#0D1020;border-radius:20px;padding:32px 24px;max-width:340px;
  width:100%;border:1px solid rgba(93,224,230,.15)}
.logo{text-align:center;font-size:2rem;margin-bottom:12px}
h1{color:white;font-size:1.1rem;font-weight:700;text-align:center;margin-bottom:4px}
.sub{color:#5a7a9b;font-size:.8rem;text-align:center;margin-bottom:24px}
label{color:#5a7a9b;font-size:.75rem;font-weight:600;display:block;margin-bottom:6px;text-transform:uppercase;letter-spacing:.06em}
input{width:100%;padding:14px 16px;background:rgba(255,255,255,.08);
  border:1.5px solid rgba(255,255,255,.12);border-radius:12px;color:white;
  font-size:16px;margin-bottom:16px;outline:none}
input:focus{border-color:#5DE0E6}
button{width:100%;padding:16px;background:linear-gradient(90deg,#5DE0E6,#3372E3);
  border:none;border-radius:12px;color:white;font-size:1rem;
  font-weight:700;cursor:pointer;margin-top:4px}
</style></head>
<body><div class="card">
<div class="logo">📺</div>
<h1>TODO EN UNO TV</h1>
<p class="sub">Ingresa tus credenciales desde el teléfono</p>
<form method="POST" action="/">
<label>Usuario</label>
<input type="text" name="username" autocomplete="off" autocorrect="off"
  autocapitalize="off" spellcheck="false" required>
<label>Contraseña</label>
<input type="password" name="password" required>
<button type="submit">CONECTAR EN TV →</button>
</form></div></body></html>''';

  static const String _successHtml = '''<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Listo</title>
<style>*{margin:0;padding:0;box-sizing:border-box}
body{background:#060C1B;font-family:-apple-system,sans-serif;min-height:100vh;
  display:flex;align-items:center;justify-content:center;padding:20px}
.card{background:#0D1020;border-radius:20px;padding:40px 24px;max-width:340px;
  width:100%;border:1px solid rgba(93,224,230,.25);text-align:center}
.icon{font-size:3rem;margin-bottom:16px}
h1{color:white;font-size:1.2rem;font-weight:700;margin-bottom:8px}
p{color:#5a7a9b;font-size:.9rem;line-height:1.6}
</style></head>
<body><div class="card">
<div class="icon">✅</div>
<h1>¡Conectado!</h1>
<p>Las credenciales fueron enviadas a tu TV.<br>Ya puedes cerrar esta página.</p>
</div></body></html>''';

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTwoCol = size.width > 700;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: isTwoCol
              ? _twoColumnLayout(context)
              : _singleColumnLayout(context, keyboardH),
        ),
      ),
    );
  }

  // ── Dos columnas: TV / tablet landscape ─────────────────────────────────
  Widget _twoColumnLayout(BuildContext context) => Row(
    children: [
      // ── Columna izquierda: logo ──────────────────────────────────────────
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background,
                const Color(0xFF0A1128),
              ],
            ),
            border: const Border(
              right: BorderSide(color: Colors.white10, width: 1),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRemote(width: 80, height: 160),
                const SizedBox(height: 28),
                // Wordmark estilo brandkit
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.celeste, AppColors.azul],
                  ).createShader(bounds),
                  child: const Text('TODO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      height: 1.0,
                    )),
                ),
                const Text('EN UNO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    height: 1.05,
                  )),
                const Text('TV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    height: 1.05,
                  )),
                const SizedBox(height: 16),
                const Text('Tu entretenimiento en un solo lugar',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  )),
              ],
            ),
          ),
        ),
      ),

      // ── Columna derecha: formulario ──────────────────────────────────────
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _formContent(context),
            ),
          ),
        ),
      ),
    ],
  );

  // ── Una columna: teléfono ────────────────────────────────────────────────
  Widget _singleColumnLayout(BuildContext context, double keyboardH) => Center(
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(32, 32, 32, keyboardH + 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(children: [
          AnimatedRemote(width: 54, height: 108),
          const SizedBox(height: 16),
          const Text('TODO EN UNO TV',
            style: TextStyle(color: Colors.white, fontSize: 20,
              fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 24),
          _formContent(context),
        ]),
      ),
    ),
  );

  // ── Contenido del formulario (compartido) ────────────────────────────────
  Widget _formContent(BuildContext context) => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Iniciar sesión',
        style: TextStyle(color: Colors.white,
          fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Ingresa tus credenciales para continuar',
        style: TextStyle(color: Colors.white54, fontSize: 14)),
      const SizedBox(height: 28),

      _field(ctrl: _userCtrl, focus: _userFocus, next: _passFocus,
        label: 'Usuario', icon: Icons.person_rounded,
        validator: (v) => (v?.isEmpty ?? true) ? 'Ingresa tu usuario' : null),
      const SizedBox(height: 14),
      _field(ctrl: _passCtrl, focus: _passFocus,
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

      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 48,
        child: OutlinedButton.icon(
          onPressed: _loading ? null : _openQrLogin,
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('Ingresar desde el móvil',
            style: TextStyle(fontSize: 14, letterSpacing: 0.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.celeste,
            side: BorderSide(color: AppColors.celeste.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14))),
        )),

      const SizedBox(height: 24),
      const Center(child: Text('© 2026 Todo en Uno TV',
        style: TextStyle(color: Colors.white24, fontSize: 12))),
    ]),
  );

  Widget _field({
    required TextEditingController ctrl,
    required FocusNode focus,
    FocusNode? next,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmit,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl, focusNode: focus,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white, fontSize: 16),
    textInputAction: next != null ? TextInputAction.next : TextInputAction.done,
    onFieldSubmitted: onSubmit ?? (_) { if (next != null) next.requestFocus(); },
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.celeste),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.09),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.celeste, width: 2.0)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24, width: 1.5)),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
    ),
    validator: validator,
  );
}

// ─── QR Dialog ────────────────────────────────────────────────────────────────
class _QrDialog extends StatelessWidget {
  final String url;
  const _QrDialog({required this.url});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xFF0D1020),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.smartphone, color: AppColors.celeste, size: 28),
        const SizedBox(height: 10),
        const Text('Ingresar desde el móvil',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Escanea con la cámara de tu teléfono\ny escribe tus credenciales ahí',
          style: TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: QrImageView(
            data: url, version: QrVersions.auto, size: 180,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square, color: Color(0xFF060C1B)),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square, color: Color(0xFF060C1B)),
          ),
        ),
        const SizedBox(height: 12),
        Text(url, style: const TextStyle(color: AppColors.celeste,
          fontSize: 11, fontFamily: 'monospace')),
        const SizedBox(height: 6),
        const Text('Asegúrate de estar en la misma red WiFi',
          style: TextStyle(color: Colors.white30, fontSize: 11)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white38))),
      ]),
    ),
  );
}
