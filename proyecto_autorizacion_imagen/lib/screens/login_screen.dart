import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _auth = AuthService();

  bool _ocultarClave = true;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _auth.iniciarSesion(_correoCtrl.text, _claveCtrl.text);
      // El AuthGate (main.dart) detecta la sesión y cambia a la pantalla de
      // inicio; aquí solo cerramos esta pantalla de login.
      if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.mensajeDeError(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Escribe tu correo' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _claveCtrl,
                    obscureText: _ocultarClave,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarClave ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                    onFieldSubmitted: (_) => _iniciarSesion(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                    onPressed: _cargando ? null : _iniciarSesion,
                    child: _cargando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}