import 'package:connectivity_plus/connectivity_plus.dart';

/// Envuelve connectivity_plus para que el resto de la app no dependa
/// directamente del paquete. Expone un stream de "¿hay internet ahora?"
/// (colapsando la lista de resultados que entrega el paquete) para que
/// [ServicioSincronizacion] dispare la sincronización apenas se recupera
/// la señal — la idea central del Módulo 3.
class ConectividadService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get alCambiarConexion => _connectivity.onConnectivityChanged
      .map(_algunaConexionActiva)
      .distinct();

  Future<bool> hayConexionAhora() async {
    final resultado = await _connectivity.checkConnectivity();
    return _algunaConexionActiva(resultado);
  }

  bool _algunaConexionActiva(List<ConnectivityResult> resultados) {
    return resultados.any((r) => r != ConnectivityResult.none);
  }
}
