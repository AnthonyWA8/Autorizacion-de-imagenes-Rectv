import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/perfil_usuario.dart';

class UsuariosService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('usuarios');

  Stream<List<PerfilUsuario>> usuarios() => _col.snapshots().map((s) {
        final lista = s.docs.map(PerfilUsuario.desdeFirestore).toList();
        lista.sort((a, b) =>
            a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  /// Segunda conexión a Firebase, solo para crear cuentas. Si se creara la
  /// cuenta con la conexión normal, Firebase abriría sesión con la cuenta
  /// nueva y el admin quedaría fuera de la suya.
  Future<FirebaseApp> _appCreadora() async {
    for (final app in Firebase.apps) {
      if (app.name == 'creador') return app;
    }
    return Firebase.initializeApp(name: 'creador', options: Firebase.app().options);
  }

  /// Crea la cuenta de acceso (Authentication) y su perfil (Firestore).
  /// Los errores se dejan burbujear para que la pantalla explique cada caso.
  Future<void> crearUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String cargo,
    required bool esAdmin,
  }) async {
    final authSecundario = FirebaseAuth.instanceFor(app: await _appCreadora());
    try {
      final cred = await authSecundario.createUserWithEmailAndPassword(
        email: correo,
        password: contrasena,
      );
      // Este set() va por la conexión normal: lo hace el admin con su sesión.
      await _col.doc(cred.user!.uid).set({
        'nombre': nombre,
        'correo': correo,
        'cargo': cargo,
        'rol': esAdmin ? 'admin' : 'usuario',
        'activo': true,
        'creadoEn': Timestamp.now(),
      }).timeout(const Duration(seconds: 20));
    } finally {
      await authSecundario.signOut();
    }
  }

  Future<void> cambiarRol(String uid, {required bool esAdmin}) => _col
      .doc(uid)
      .update({'rol': esAdmin ? 'admin' : 'usuario'})
      .timeout(const Duration(seconds: 15));

  Future<void> cambiarActivo(String uid, {required bool activo}) => _col
      .doc(uid)
      .update({'activo': activo})
      .timeout(const Duration(seconds: 15));

  /// Le llega al usuario un correo para que elija su propia contraseña.
  Future<void> enviarRestablecimiento(String correo) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
}