import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/proyecto.dart';

class ProyectosService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _proyectos =>
      _db.collection('proyectos');

  Stream<List<Proyecto>> proyectos() => _proyectos
      .orderBy('creadoEn', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Proyecto.desdeFirestore).toList());

  Stream<List<Subproyecto>> subproyectos(String proyectoId) => _proyectos
      .doc(proyectoId)
      .collection('subproyectos')
      .orderBy('creadoEn', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Subproyecto.desdeFirestore).toList());

  // No se hace await a propósito: sin internet, el Future de set() no termina
  // hasta que el servidor confirme. Con unawaited, el documento aparece al
  // instante en la lista (Firestore lo sirve desde su caché local) y se sube
  // solo cuando vuelve la conexión.
  void crearProyecto({
    required String nombre,
    required String cliente,
    required String creadoPor,
  }) {
    unawaited(_proyectos.doc().set({
      'nombre': nombre,
      'cliente': cliente,
      'creadoPor': creadoPor,
      'creadoEn': Timestamp.now(),
    }));
  }

  void crearSubproyecto({
    required String proyectoId,
    required String nombre,
    required String creadoPor,
  }) {
    unawaited(_proyectos.doc(proyectoId).collection('subproyectos').doc().set({
      'nombre': nombre,
      'creadoPor': creadoPor,
      'creadoEn': Timestamp.now(),
    }));
  }
    // ---------- Firmas (registros) de un proyecto / sub-proyecto ----------

  CollectionReference<Map<String, dynamic>> get _registros =>
      _db.collection('registros_autorizacion');

  /// Cuántas firmas tiene cada sub-proyecto de un proyecto (id -> cantidad).
  Stream<Map<String, int>> conteoPorSubproyecto(String proyectoId) => _registros
      .where('proyectoId', isEqualTo: proyectoId)
      .snapshots()
      .map((s) {
        final conteo = <String, int>{};
        for (final d in s.docs) {
          final id = d.data()['subproyectoId'] as String?;
          if (id != null) conteo[id] = (conteo[id] ?? 0) + 1;
        }
        return conteo;
      });

  /// Firmas de un sub-proyecto, la más reciente primero. Se ordena aquí y no
  /// en Firestore para no tener que crear un índice compuesto.
  Stream<List<Map<String, dynamic>>> registrosDeSubproyecto(String subproyectoId) =>
      _registros
          .where('subproyectoId', isEqualTo: subproyectoId)
          .snapshots()
          .map((s) {
            final lista = s.docs.map((d) => {...d.data(), 'id': d.id}).toList();
            lista.sort((a, b) => ((b['creadoEn'] as String?) ?? '')
                .compareTo((a['creadoEn'] as String?) ?? ''));
            return lista;
          });

  // ---------- Eliminar (solo admin; las reglas de Firestore lo exigen) ----------

  // Las firmas NO se tocan: son evidencia de consentimiento.
  void eliminarSubproyecto({
    required String proyectoId,
    required String subproyectoId,
  }) {
    unawaited(_proyectos
        .doc(proyectoId)
        .collection('subproyectos')
        .doc(subproyectoId)
        .delete());
  }

  void eliminarProyecto(String proyectoId) {
    unawaited(_eliminarProyecto(proyectoId));
  }

  // Firestore no borra las subcolecciones solo: hay que borrar los
  // sub-proyectos a mano junto con el proyecto.
  Future<void> _eliminarProyecto(String proyectoId) async {
    final ref = _proyectos.doc(proyectoId);
    final subs = await ref.collection('subproyectos').get();
    final lote = _db.batch();
    for (final s in subs.docs) {
      lote.delete(s.reference);
    }
    lote.delete(ref);
    await lote.commit();
  }
}