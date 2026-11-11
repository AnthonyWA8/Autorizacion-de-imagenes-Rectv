enum Rol {
  admin,
  usuario;

  static Rol desdeTexto(String? valor) => Rol.values.firstWhere(
        (r) => r.name == valor,
        orElse: () => Rol.usuario,
      );
}

class Usuario {
  Usuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.rol,
  });

  final String uid;
  final String nombre;
  final String correo;
  final Rol rol;

  bool get esAdmin => rol == Rol.admin;

  factory Usuario.desdeFirestore(String uid, Map<String, dynamic> datos) {
    return Usuario(
      uid: uid,
      nombre: datos['nombre'] as String? ?? '',
      correo: datos['correo'] as String? ?? '',
      rol: Rol.desdeTexto(datos['rol'] as String?),
    );
  }
}