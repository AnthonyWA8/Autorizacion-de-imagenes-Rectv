/// Modelo central del proyecto: un registro por cada participante que llena
/// el formulario de autorización de uso de imagen.
///
/// Se pensó para vivir primero en el dispositivo (offline-first, Módulo 3) y
/// sincronizarse después con Firestore/Storage. Los campos [documentoFirmaId]
/// y [estadoFirma] quedan listos para cuando se integre la firma electrónica
/// (Módulo 1, SignWell) y [videoId] es la referencia que usará el módulo de
/// verificación facial (Módulo 2, AWS Rekognition CompareFaces) para saber
/// contra qué video comparar la selfie.
library;

/// Estado de sincronización de un registro con el backend (Firestore/Storage).
enum EstadoSync {
  pendiente,
  sincronizado,
  error;

  static EstadoSync desdeTexto(String valor) => EstadoSync.values.firstWhere(
        (e) => e.name == valor,
        orElse: () => EstadoSync.pendiente,
      );
}

/// Estado del documento de autorización dentro del flujo de firma electrónica.
enum EstadoFirma {
  pendiente,
  enviado,
  firmado;

  static EstadoFirma desdeTexto(String valor) => EstadoFirma.values.firstWhere(
        (e) => e.name == valor,
        orElse: () => EstadoFirma.pendiente,
      );
}

class RegistroAutorizacion {
  RegistroAutorizacion({
    required this.id,
    required this.nombreCompleto,
    required this.documentoIdentidad,
    required this.evento,
    required this.videoId,
    required this.fotoLocalPath,
    required this.autorizaUsoImagen,
    required this.autorizaDatoBiometrico,
    required this.creadoEn,
    this.fotoUrlRemota,
    this.documentoFirmaId,
    this.estadoFirma = EstadoFirma.pendiente,
    this.estadoSync = EstadoSync.pendiente,
    this.sincronizadoEn,
    this.errorSync,
    this.proyectoId,
    this.subproyectoId,
  });

  /// Identificador generado localmente (uuid v4) — existe desde el instante
  /// en que se guarda el formulario, sin depender de que haya internet.
  final String id;

  final String nombreCompleto;
  final String documentoIdentidad;

  /// Nombre del rodaje / anuncio para el que se firma la autorización.
  final String evento;

  final String? proyectoId;
  final String? subproyectoId;

  /// Referencia al video final; el módulo de verificación facial la usa para
  /// saber contra qué grabación comparar esta selfie.
  final String videoId;

  /// Ruta local (en el dispositivo) del archivo de la selfie tomada al
  /// llenar el formulario. Se conserva SIEMPRE, incluso tras sincronizar,
  /// para poder reintentar una comparación facial sin volver a pedir la foto.
  final String fotoLocalPath;

  /// URL en Firebase Storage, solo se llena cuando hay internet y el
  /// servicio de sincronización sube el archivo.
  final String? fotoUrlRemota;

  /// Consentimiento explícito para el uso de la imagen en el video/anuncio.
  final bool autorizaUsoImagen;

  /// Consentimiento explícito y SEPARADO para el tratamiento del rostro como
  /// dato biométrico (Ley 1581 de 2012, Colombia: es un dato sensible y debe
  /// autorizarse aparte, informando que existe una alternativa no biométrica).
  final bool autorizaDatoBiometrico;

  /// Id del documento en el proveedor de firma electrónica (Módulo 1). Queda
  /// en null hasta que se integre ese módulo.
  final String? documentoFirmaId;
  final EstadoFirma estadoFirma;

  final EstadoSync estadoSync;
  final String? errorSync;

  final DateTime creadoEn;
  final DateTime? sincronizadoEn;

  RegistroAutorizacion copiarCon({
    String? fotoUrlRemota,
    String? documentoFirmaId,
    EstadoFirma? estadoFirma,
    EstadoSync? estadoSync,
    String? errorSync,
    DateTime? sincronizadoEn,
  }) {
    return RegistroAutorizacion(
      id: id,
      nombreCompleto: nombreCompleto,
      documentoIdentidad: documentoIdentidad,
      evento: evento,
      proyectoId: proyectoId,
      subproyectoId: subproyectoId,
      videoId: videoId,
      fotoLocalPath: fotoLocalPath,
      autorizaUsoImagen: autorizaUsoImagen,
      autorizaDatoBiometrico: autorizaDatoBiometrico,
      creadoEn: creadoEn,
      fotoUrlRemota: fotoUrlRemota ?? this.fotoUrlRemota,
      documentoFirmaId: documentoFirmaId ?? this.documentoFirmaId,
      estadoFirma: estadoFirma ?? this.estadoFirma,
      estadoSync: estadoSync ?? this.estadoSync,
      errorSync: errorSync,
      sincronizadoEn: sincronizadoEn ?? this.sincronizadoEn,
    );
  }

  /// Serialización para el archivo JSON local (la "cola offline" del Módulo 3).
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombreCompleto': nombreCompleto,
        'documentoIdentidad': documentoIdentidad,
        'evento': evento,
        'proyectoId': proyectoId,
        'subproyectoId': subproyectoId,
        'videoId': videoId,
        'fotoLocalPath': fotoLocalPath,
        'fotoUrlRemota': fotoUrlRemota,
        'autorizaUsoImagen': autorizaUsoImagen,
        'autorizaDatoBiometrico': autorizaDatoBiometrico,
        'documentoFirmaId': documentoFirmaId,
        'estadoFirma': estadoFirma.name,
        'estadoSync': estadoSync.name,
        'errorSync': errorSync,
        'creadoEn': creadoEn.toIso8601String(),
        'sincronizadoEn': sincronizadoEn?.toIso8601String(),
      };

  factory RegistroAutorizacion.fromJson(Map<String, dynamic> json) {
    return RegistroAutorizacion(
      id: json['id'] as String,
      nombreCompleto: json['nombreCompleto'] as String,
      documentoIdentidad: json['documentoIdentidad'] as String,
      evento: json['evento'] as String,
      proyectoId: json['proyectoId'] as String?,
      subproyectoId: json['subproyectoId'] as String?,
      videoId: json['videoId'] as String,
      fotoLocalPath: json['fotoLocalPath'] as String,
      fotoUrlRemota: json['fotoUrlRemota'] as String?,
      autorizaUsoImagen: json['autorizaUsoImagen'] as bool,
      autorizaDatoBiometrico: json['autorizaDatoBiometrico'] as bool,
      documentoFirmaId: json['documentoFirmaId'] as String?,
      estadoFirma: EstadoFirma.desdeTexto(json['estadoFirma'] as String? ?? 'pendiente'),
      estadoSync: EstadoSync.desdeTexto(json['estadoSync'] as String? ?? 'pendiente'),
      errorSync: json['errorSync'] as String?,
      creadoEn: DateTime.parse(json['creadoEn'] as String),
      sincronizadoEn: json['sincronizadoEn'] == null
          ? null
          : DateTime.parse(json['sincronizadoEn'] as String),
    );
  }

  /// Lo que se sube a Firestore: nunca incluye la ruta local del archivo
  /// (no tiene sentido fuera del dispositivo), solo la URL remota una vez
  /// subida la foto a Storage.
  Map<String, dynamic> toFirestore() => {
        'nombreCompleto': nombreCompleto,
        'documentoIdentidad': documentoIdentidad,
        'evento': evento,
        'proyectoId': proyectoId,
        'subproyectoId': subproyectoId,
        'videoId': videoId,
        'fotoUrlRemota': fotoUrlRemota,
        'autorizaUsoImagen': autorizaUsoImagen,
        'autorizaDatoBiometrico': autorizaDatoBiometrico,
        'documentoFirmaId': documentoFirmaId,
        'estadoFirma': estadoFirma.name,
        'creadoEn': creadoEn.toIso8601String(),
        'sincronizadoEn': DateTime.now().toIso8601String(),
      };
}
