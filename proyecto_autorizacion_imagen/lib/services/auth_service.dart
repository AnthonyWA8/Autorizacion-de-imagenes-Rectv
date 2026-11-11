import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario.dart';

class PerfilNoEncontrado implements Exception {
  const PerfilNoEncontrado();
}

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  Future<void> iniciarSesion(String correo, String clave) async {
    await _auth.signInWithEmailAndPassword(email: correo.trim(), password: clave);
  }

  Future<void> cerrarSesion() => _auth.signOut();

  /// Lee el perfil (nombre y rol) de `usuarios/{uid}`. Sin este documento la
  /// cuenta existe en Authentication pero la app no sabe qué rol darle.
  Future<Usuario> cargarUsuario(User user) async {
    final doc = await _db.collection('usuarios').doc(user.uid).get();
    if (!doc.exists) throw const PerfilNoEncontrado();
    return Usuario.desdeFirestore(user.uid, doc.data()!);
  }

  static String mensajeDeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos';
      case 'invalid-email':
        return 'El correo no tiene un formato válido';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo de nuevo';
      case 'network-request-failed':
        return 'Sin conexión. Para iniciar sesión por primera vez se necesita internet';
      default:
        return 'No se pudo iniciar sesión (${e.code})';
    }
  }
}