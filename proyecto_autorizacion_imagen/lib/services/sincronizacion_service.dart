import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';
import '../models/registro_autorizacion.dart';
import 'almacenamiento_local_service.dart';
import 'conectividad_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResultadoSincronizacion {
  ResultadoSincronizacion({required this.sincronizados, required this.fallidos});
  final int sincronizados;
  final int fallidos;
}

bool firebaseListo = false;

class SincronizacionService {
  SincronizacionService({
    AlmacenamientoLocalService? almacenamiento,
    ConectividadService? conectividad,
  })  : _almacenamiento = almacenamiento ?? AlmacenamientoLocalService(),
        _conectividad = conectividad ?? ConectividadService();

  final AlmacenamientoLocalService _almacenamiento;
  final ConectividadService _conectividad;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const _coleccion = 'registros_autorizacion';

  StreamSubscription<bool>? _suscripcionConectividad;

  void iniciarEscuchaAutomatica() {
    _suscripcionConectividad ??=
        _conectividad.alCambiarConexion.listen((hayInternet) {
      if (hayInternet) {
        sincronizarPendientes();
      }
    });
  }

  void detener() {
    _suscripcionConectividad?.cancel();
    _suscripcionConectividad = null;
  }

  Future<ResultadoSincronizacion> sincronizarPendientes() async {
    if (!firebaseListo) {
      return ResultadoSincronizacion(sincronizados: 0, fallidos: 0);
    }

    if (FirebaseAuth.instance.currentUser == null) {
      // Sin sesión las reglas de Firestore rechazarían la escritura.
      return ResultadoSincronizacion(sincronizados: 0, fallidos: 0);
    }

    final hayInternet = await _conectividad.hayConexionAhora();
    if (!hayInternet) {
      return ResultadoSincronizacion(sincronizados: 0, fallidos: 0);
    }

    final pendientes = await _almacenamiento.obtenerPendientes();
    var sincronizados = 0;
    var fallidos = 0;

    for (final registro in pendientes) {
      try {
        final actualizado = await _sincronizarUno(registro);
        await _almacenamiento.actualizarRegistro(actualizado);
        sincronizados++;
      } on FirebaseException catch (e) {
        await _almacenamiento.actualizarRegistro(
          registro.copiarCon(
            estadoSync: EstadoSync.error,
            errorSync: 'Firebase: ${e.code}',
          ),
        );
        fallidos++;
      } on HttpException catch (e) {
        await _almacenamiento.actualizarRegistro(
          registro.copiarCon(
            estadoSync: EstadoSync.error,
            errorSync: 'Supabase: ${e.message}',
          ),
        );
        fallidos++;
      } on SocketException {
        await _almacenamiento.actualizarRegistro(
          registro.copiarCon(
            estadoSync: EstadoSync.pendiente,
            errorSync: 'Se perdió la conexión durante la subida',
          ),
        );
        fallidos++;
      } on TimeoutException {
        await _almacenamiento.actualizarRegistro(
          registro.copiarCon(
            estadoSync: EstadoSync.pendiente,
            errorSync: 'Tiempo de espera agotado, se reintentará',
          ),
        );
        fallidos++;
      } catch (e) {
        await _almacenamiento.actualizarRegistro(
          registro.copiarCon(
            estadoSync: EstadoSync.error,
            errorSync: e.toString(),
          ),
        );
        fallidos++;
      }
    }

    return ResultadoSincronizacion(sincronizados: sincronizados, fallidos: fallidos);
  }

  Future<RegistroAutorizacion> _sincronizarUno(RegistroAutorizacion registro) async {
    String? urlFoto = registro.fotoUrlRemota;

    if (urlFoto == null) {
      final archivo = File(registro.fotoLocalPath);
      if (!await archivo.exists()) {
        throw StateError('La foto local ${registro.fotoLocalPath} ya no existe');
      }
      urlFoto = await _subirFotoASupabase(archivo, registro.id);
    }

    final actualizado = registro.copiarCon(
      fotoUrlRemota: urlFoto,
      estadoSync: EstadoSync.sincronizado,
      errorSync: null,
      sincronizadoEn: DateTime.now(),
    );

    await _firestore
        .collection(_coleccion)
        .doc(actualizado.id)
        .set(actualizado.toFirestore())
        .timeout(const Duration(seconds: 20));

    return actualizado;
  }

  Future<String> _subirFotoASupabase(File archivo, String idRegistro) async {
    final ruta = '$idRegistro.jpg';
    final uri = Uri.parse(
      '${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.bucket}/$ruta',
    );

    final bytes = await archivo.readAsBytes();

    final respuesta = await http
        .post(
          uri,
          headers: {
            'apikey': SupabaseConfig.anonKey,
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 30));

    if (respuesta.statusCode != 200) {
      throw HttpException(
        'HTTP ${respuesta.statusCode} — revisa url/anonKey/bucket en '
        'supabase_config.dart, y que el bucket tenga una política que '
        'permita subir (INSERT) al rol anon (${respuesta.body})',
      );
    }

    return '${SupabaseConfig.url}/storage/v1/object/public/'
        '${SupabaseConfig.bucket}/$ruta';
  }
}