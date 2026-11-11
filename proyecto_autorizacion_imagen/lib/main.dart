import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'models/usuario.dart';
import 'screens/bienvenida_screen.dart';
import 'screens/inicio_screen.dart';
import 'services/auth_service.dart';
import 'services/sincronizacion_service.dart';
import 'widgets/guardia_activa.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseListo = true;
  } catch (e) {
    debugPrint('Firebase no se pudo inicializar todavía: $e');
  }

  if (firebaseListo) {
    SincronizacionService().iniciarEscuchaAutomatica();
  }

  runApp(const AutorizacionImagenApp());
}

class AutorizacionImagenApp extends StatelessWidget {
  const AutorizacionImagenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Autorización de uso de imagen',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F8F7A),
        useMaterial3: true,
      ),
      home: AuthGate(),
    );
  }
}

/// Decide qué pantalla mostrar según la sesión: sin sesión → bienvenida/login;
/// con sesión → carga el perfil (rol) y muestra el panel de inicio.
/// Firebase Auth guarda la sesión en el dispositivo, así que al reabrir la app
/// (incluso sin internet) el usuario sigue dentro.
class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    if (!firebaseListo) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Firebase no está configurado todavía. Ver README.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _auth.cambiosDeSesion,
      builder: (context, sesion) {
        if (sesion.connectionState == ConnectionState.waiting) {
          return const _Cargando();
        }
        final user = sesion.data;
        if (user == null) return const BienvenidaScreen();

        return FutureBuilder<Usuario>(
          future: _auth.cargarUsuario(user),
          builder: (context, perfil) {
            if (perfil.connectionState != ConnectionState.done) {
              return const _Cargando();
            }
            if (perfil.hasError) {
              return _ErrorPerfil(error: perfil.error!, auth: _auth);
            }
            return GuardiaActiva(child: InicioScreen(usuario: perfil.data!));
          },
        );
      },
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorPerfil extends StatelessWidget {
  const _ErrorPerfil({required this.error, required this.auth});

  final Object error;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final sinPerfil = error is PerfilNoEncontrado;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sinPerfil
                    ? 'Tu cuenta existe pero no tiene perfil asignado. Pídele al administrador que lo cree.'
                    : 'No se pudo cargar tu perfil. Revisa la conexión e inténtalo de nuevo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: auth.cerrarSesion,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}