import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Botón/preview para tomar la selfie del firmante. Solo usa la cámara
/// (no la galería): esta foto es la que después el Módulo 2 comparará
/// contra los rostros del video, así que debe tomarse en el momento, no
/// elegirse de fotos viejas.
class CapturaSelfieWidget extends StatefulWidget {
  const CapturaSelfieWidget({super.key, required this.alCapturar});

  /// Se llama con la ruta del archivo apenas se toma la foto.
  final ValueChanged<String> alCapturar;

  @override
  State<CapturaSelfieWidget> createState() => _CapturaSelfieWidgetState();
}

class _CapturaSelfieWidgetState extends State<CapturaSelfieWidget> {
  final ImagePicker _picker = ImagePicker();
  String? _rutaFoto;
  String? _error;

  Future<void> _tomarFoto() async {
    setState(() => _error = null);
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      if (foto == null) return; // el usuario canceló
      setState(() => _rutaFoto = foto.path);
      widget.alCapturar(foto.path);
    } catch (e) {
      // Sin permiso de cámara, sin cámara disponible (emulador), etc. Se
      // muestra el motivo en vez de fallar en silencio.
      setState(() => _error = 'No se pudo abrir la cámara: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rutaFoto != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_rutaFoto!), height: 220, fit: BoxFit.cover),
          )
        else
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.face_retouching_natural, size: 64),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _tomarFoto,
          icon: const Icon(Icons.camera_alt),
          label: Text(_rutaFoto == null ? 'Tomar selfie' : 'Tomar otra vez'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
