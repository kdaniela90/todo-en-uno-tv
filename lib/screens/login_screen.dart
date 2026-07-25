import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:qr_flutter/qr_flutter.dart';
import '../services/config_service.dart';
import '../services/storage_service.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';

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

  // QR local server (auto-start en initState)
  HttpServer? _qrServer;
  String? _qrUrl;
  bool _qrReceived = false;
  String _logoDataUri = '';

  // URL del servidor gestionada remotamente por ConfigService (config.json en GitHub)

  @override
  void initState() {
    super.initState();
    _autoStartQrServer();
  }

  @override
  void dispose() {
    _userCtrl.dispose(); _passCtrl.dispose();
    _userFocus.dispose(); _passFocus.dispose();
    _qrServer?.close(force: true);
    super.dispose();
  }

  // ── Auto-start QR server ─────────────────────────────────────────────────
  Future<void> _autoStartQrServer() async {
    // Logo como base64 para el HTML del móvil
    try {
      final bytes = await rootBundle.load('assets/images/logo.png');
      _logoDataUri = 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    } catch (_) {}

    String? ip;
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      // Preferir interfaz WiFi (wlan0, wlan1, etc.)
      NetworkInterface? selected;
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.startsWith('wlan') || name.startsWith('wifi') || name.startsWith('wl')) {
          selected = iface;
          break;
        }
      }
      // Si no hay WiFi, usar primera interfaz que no sea loopback ni virtual
      selected ??= interfaces.where((i) {
        final n = i.name.toLowerCase();
        return !n.startsWith('lo') && !n.startsWith('dummy') && !n.startsWith('v');
      }).firstOrNull;
      ip = selected?.addresses.where((a) => !a.isLoopback).firstOrNull?.address;
    } catch (_) {}
    if (ip == null) return;

    HttpServer? server;
    for (final port in [8765, 8766, 8767]) {
      try { server = await HttpServer.bind(InternetAddress.anyIPv4, port); break; }
      catch (_) {}
    }
    if (server == null) return;

    _qrServer = server;
    final url = 'http://$ip:${server.port}';
    if (mounted) setState(() => _qrUrl = url);

    server.listen((req) async {
      if (_qrReceived) { req.response.close(); return; }
      req.response.headers.set('Access-Control-Allow-Origin', '*');
      req.response.headers.set('Content-Type', 'text/html; charset=utf-8');

      if (req.method == 'POST') {
        final body = await utf8.decoder.bind(req).join();
        final params = Uri.splitQueryString(body);
        final user = params['username'] ?? '';
        final pass = params['password'] ?? '';
        req.response.write(_successHtml);
        await req.response.flush();
        await req.response.close();
        if (user.isNotEmpty && pass.isNotEmpty && mounted) {
          _qrReceived = true;
          setState(() { _userCtrl.text = user; _passCtrl.text = pass; });
          await _qrServer?.close(force: true);
          _qrServer = null;
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) _login();
        }
      } else {
        req.response.write(_loginHtml(url, _logoDataUri));
        await req.response.flush();
        await req.response.close();
      }
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });

    final service = XtreamService(
      server: ConfigService.serverUrl,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim());
    final result = await service.login();
    if (!mounted) return;

    if (result != null && result['user_info'] != null) {
      final expRaw = result['user_info']['exp_date']?.toString() ?? '';
      await StorageService.saveCredentials(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        server: ConfigService.serverUrl, expDate: expRaw);
      Navigator.pushReplacementNamed(context, '/hub', arguments: {
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'server': ConfigService.serverUrl, 'exp_date': expRaw,
      });
    } else {
      setState(() {
        _error = 'Usuario o contraseña incorrectos.';
        _loading = false;
      });
    }
  }

  // ── Mostrar diálogo QR (modo una columna) ────────────────────────────────
  void _showQrDialog() {
    if (_qrUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay conexión WiFi activa'), backgroundColor: Colors.red));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _QrDialog(url: _qrUrl!),
    );
  }

  static String _loginHtml(String url, String logoDataUri) => '''<!DOCTYPE html>
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
.logo{text-align:center;margin-bottom:16px}
.logo img{width:160px;height:auto;display:inline-block}
.logo-fallback{color:white;font-size:1.4rem;font-weight:700;letter-spacing:2px}
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
<div class="logo">
${logoDataUri.isNotEmpty ? '<img src="$logoDataUri" alt="Todo en Uno TV">' : '<div class="logo-fallback">TODO EN UNO TV</div>'}
</div>
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
<div class="icon">&#10003;</div>
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
      // ── Columna izquierda: logo animado ──────────────────────────────────
      Expanded(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF060C1B), Color(0xFF0A1128)],
            ),
            border: Border(right: BorderSide(color: Colors.white10, width: 1)),
          ),
          child: const Center(child: _AnimatedLogo()),
        ),
      ),

      // ── Columna derecha: formulario + QR inline ───────────────────────────
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formContent(context),
                  if (_qrUrl != null) ...[
                    const SizedBox(height: 28),
                    _QrInline(url: _qrUrl!),
                  ],
                  const SizedBox(height: 24),
                  const Center(child: Text('© 2026 Todo en Uno TV',
                    style: TextStyle(color: Colors.white24, fontSize: 12))),
                ],
              ),
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
      padding: EdgeInsets.fromLTRB(32, 36, 32, keyboardH + 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(children: [
          Image.asset('assets/images/logo.png', width: 120, fit: BoxFit.contain),
          const SizedBox(height: 28),
          _formContent(context),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _showQrDialog,
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

// ─── Logo animado (columna izquierda TV) ─────────────────────────────────────
class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();
  @override State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;
  late final Animation<double> _shift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _glow  = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _shift = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo con halo pulsante
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5DE0E6).withOpacity(_glow.value * 0.25),
                  blurRadius: 60, spreadRadius: 20),
                BoxShadow(
                  color: const Color(0xFF3372E3).withOpacity(_glow.value * 0.15),
                  blurRadius: 80, spreadRadius: 10),
              ],
            ),
          ),
          Image.asset('assets/images/logo.png', width: 160, fit: BoxFit.contain),
        ]),

        const SizedBox(height: 28),

        // Wordmark con gradiente animado
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFF5DE0E6), Color(0xFF3372E3),
              Color(0xFF7426EF), Color(0xFF5DE0E6),
            ],
            stops: [
              (_shift.value * 0.5).clamp(0.0, 0.9),
              (0.35 + _shift.value * 0.3).clamp(0.1, 0.95),
              (0.65 + _shift.value * 0.2).clamp(0.2, 1.0),
              (1.0).clamp(0.3, 1.0),
            ],
          ).createShader(bounds),
          child: const Column(children: [
            Text('TODO EN UNO',
              style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900, letterSpacing: 4)),
            Text('TV',
              style: TextStyle(color: Colors.white, fontSize: 36,
                fontWeight: FontWeight.w900, letterSpacing: 8, height: 0.9)),
          ]),
        ),

        const SizedBox(height: 16),
        Text('Tu entretenimiento en un solo lugar',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3 + _glow.value * 0.2),
            fontSize: 12, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        // Línea decorativa
        CustomPaint(
          size: const Size(160, 3),
          painter: _GradientLinePainter(progress: _shift.value),
        ),
      ],
    ),
  );
}

class _GradientLinePainter extends CustomPainter {
  final double progress;
  const _GradientLinePainter({required this.progress});
  @override bool shouldRepaint(_GradientLinePainter o) => o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * progress * 0.4, 0), Offset(size.width, 0),
        const [Color(0xFF5DE0E6), Color(0xFF3372E3), Color(0xFF7426EF)],
        [0.0, 0.5, 1.0])
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height / 2),
      Offset(size.width, size.height / 2), paint);
  }
}

// ─── QR inline (columna derecha TV) ──────────────────────────────────────────
class _QrInline extends StatelessWidget {
  final String url;
  const _QrInline({required this.url});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.celeste.withOpacity(0.2)),
    ),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.smartphone, color: AppColors.celeste, size: 18),
        const SizedBox(width: 8),
        const Text('Ingresar desde el móvil',
          style: TextStyle(color: Colors.white70, fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      const Text(
        'Escanea con la cámara y escribe tus credenciales en el teléfono',
        style: TextStyle(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: QrImageView(
          data: url, version: QrVersions.auto, size: 160,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square, color: Color(0xFF060C1B)),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square, color: Color(0xFF060C1B)),
        ),
      ),
      const SizedBox(height: 8),
      const Text('Misma red WiFi requerida',
        style: TextStyle(color: Colors.white24, fontSize: 10)),
    ]),
  );
}

// ─── QR Dialog (modo una columna / teléfono) ─────────────────────────────────
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
