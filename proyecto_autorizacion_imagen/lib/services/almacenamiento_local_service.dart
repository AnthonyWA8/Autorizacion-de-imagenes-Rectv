import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/registro_autorizacion.dart';

/// La "cola offline" del Módulo 3: todo registro se guarda aquí PRIMERO,
/// exista o no internet. [ServicioSincronizacion] lee de aquí lo pendiente
/// cuando vuelve la conexión.
///
/// Se usa un archivo `registros.json` (una lista) en el directorio de
/// documentos de la app, más una subcarpeta `selfies/` con las fotos. Es
/// deliberadamente simple (nada de SQLite ni paquetes de sync como
/// WatermelonDB): para el volumen de un rodaje, un archivo JSON de lectura y
/// escritura completa es más que suficiente y muy fácil de auditar en el
/// checkpoint de la Fase 2 ("¿el agente manejó cada caso, o solo envolvió en
/// try/catch?").
class AlmacenamientoLocalService {
  static const _nombreArchivoIndice = 'registros.json';
  static const _nombreCarpetaSelfies = 'selfies';

  Future<Directory> _directorioBase() => getApplicationDocumentsDirectory();

  Future<File> _archivoIndice() async {
    final dir = await _directorioBase();
    return File('${dir.path}/$_nombreArchivoIndice');
  }

  Future<Directory> _carpetaSelfies() async {
    final dir = await _directorioBase();
    final carpeta = Directory('${dir.path}/$_nombreCarpetaSelfies');
    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }
    return carpeta;
  }

  /// Copia la foto tomada por la cámara a un lugar estable dentro del
  /// almacenamiento de la app (la ruta que entrega el image_picker puede
  /// vivir en una carpeta temporal que el sistema operativo limpia).
  Future<String> guardarFotoLocal({
    required String idRegistro,
    required String rutaFotoOriginal,
  }) async {
    final carpeta = await _carpetaSelfies();
    final extension = rutaFotoOriginal.split('.').last;
    final destino = File('${carpeta.path}/$idRegistro.$extension');
    await File(rutaFotoOriginal).copy(destino.path);
    return destino.path;
  }

  Future<List<RegistroAutorizacion>> obtenerTodos() async {
    final archivo = await _archivoIndice();
    if (!await archivo.exists()) return [];

    try {
      final contenido = await archivo.readAsString();
      if (contenido.trim().isEmpty) return [];
      final lista = jsonDecode(contenido) as List<dynamic>;
      return lista
          .map((e) => RegistroAutorizacion.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException {
      // Índice corrupto (por ejemplo, la app se cerró a mitad de una
      // escritura): no perdemos las fotos, pero avisamos en vez de fallar
      // en silencio — el checkpoint de la Fase 2 pide justo esto.
      final respaldo = File('${archivo.path}.corrupto-${DateTime.now().millisecondsSinceEpoch}');
      await archivo.copy(respaldo.path);
      return [];
    }
  }

  Future<List<RegistroAutorizacion>> obtenerPendientes() async {
    final todos = await obtenerTodos();
    return todos.where((r) => r.estadoSync != EstadoSync.sincronizado).toList();
  }

  Future<void> _guardarTodos(List<RegistroAutorizacion> registros) async {
    final archivo = await _archivoIndice();
    final json = jsonEncode(registros.map((r) => r.toJson()).toList());
    // Escritura a un archivo temporal y luego rename: evita dejar el índice
    // a medio escribir si la app se cierra justo en ese momento.
    final temporal = File('${archivo.path}.tmp');
    await temporal.writeAsString(json, flush: true);
    await temporal.rename(archivo.path);
  }

  Future<void> agregarRegistro(RegistroAutorizacion registro) async {
    final todos = await obtenerTodos();
    todos.add(registro);
    await _guardarTodos(todos);
  }

  Future<void> actualizarRegistro(RegistroAutorizacion actualizado) async {
    final todos = await obtenerTodos();
    final indice = todos.indexWhere((r) => r.id == actualizado.id);
    if (indice == -1) {
      todos.add(actualizado);
    } else {
      todos[indice] = actualizado;
    }
    await _guardarTodos(todos);
  }
}
