import 'package:cloud_firestore/cloud_firestore.dart';

class Proyecto {
  Proyecto({
    required this.id,
    required this.nombre,
    required this.cliente,
    required this.creadoEn,
  });

  final String id;
  final String nombre;
  final String cliente;
  final DateTime creadoEn;

  factory Proyecto.desdeFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Proyecto(
      id: doc.id,
      nombre: d['nombre'] as String? ?? '',
      cliente: d['cliente'] as String? ?? '',
      creadoEn: (d['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Subproyecto {
  Subproyecto({
    required this.id,
    required this.nombre,
    required this.creadoEn,
  });

  final String id;
  final String nombre;
  final DateTime creadoEn;

  factory Subproyecto.desdeFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Subproyecto(
      id: doc.id,
      nombre: d['nombre'] as String? ?? '',
      creadoEn: (d['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}