import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfil de una persona que usa la app (documento de la colección `usuarios`).
class PerfilUsuario {
  PerfilUsuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.cargo,
    required this.esAdmin,
    required this.activo,
  });

  final String uid;
  final String nombre;
  final String correo;
  final String cargo;
  final bool esAdmin;
  final bool activo;

  factory PerfilUsuario.desdeFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PerfilUsuario(
      uid: doc.id,
      nombre: d['nombre'] as String? ?? '',
      correo: d['correo'] as String? ?? '',
      cargo: d['cargo'] as String? ?? '',
      esAdmin: d['rol'] == 'admin',
      activo: d['activo'] as bool? ?? true,
    );
  }
}