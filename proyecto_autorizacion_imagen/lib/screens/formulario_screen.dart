import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/registro_autorizacion.dart';
import '../services/almacenamiento_local_service.dart';
import '../services/sincronizacion_service.dart';
import '../widgets/captura_selfie_widget.dart';
import 'lista_registros_screen.dart';
import '../models/proyecto.dart';

/// Pantalla principal: el formulario que llena cada participante antes de
/// aparecer en el video. Guarda SIEMPRE de forma local al tocar "Guardar",
/// haya o no haya internet — ese es el punto entero del Módulo 3.
class FormularioScreen extends StatefulWidget {
       const FormularioScreen({
       super.key,
       required this.proyecto,
       required this.subproyecto,
     });

     final Proyecto proyecto;
     final Subproyecto subproyecto;

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _videoIdCtrl = TextEditingController();

  bool _autorizaUsoImagen = false;
  bool _autorizaDatoBiometrico = false;
  String? _rutaFotoTemporal;
  bool _guardando = false;

  final _almacenamiento = AlmacenamientoLocalService();
  final _sincronizacion = SincronizacionService();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _documentoCtrl.dispose();
    _videoIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_rutaFotoTemporal == null) {
      _mostrarMensaje('Falta tomar la selfie del firmante');
      return;
    }
    if (!_autorizaUsoImagen) {
      _mostrarMensaje('El participante debe autorizar el uso de su imagen');
      return;
    }

    setState(() => _guardando = true);
    try {
      final id = const Uuid().v4();
      final rutaFotoLocal = await _almacenamiento.guardarFotoLocal(
        idRegistro: id,
        rutaFotoOriginal: _rutaFotoTemporal!,
      );

      final registro = RegistroAutorizacion(
        id: id,
        nombreCompleto: _nombreCtrl.text.trim(),
        documentoIdentidad: _documentoCtrl.text.trim(),
        evento: '${widget.proyecto.nombre} · ${widget.subproyecto.nombre}',
        proyectoId: widget.proyecto.id,
        subproyectoId: widget.subproyecto.id,
        videoId: _videoIdCtrl.text.trim(),
        fotoLocalPath: rutaFotoLocal,
        autorizaUsoImagen: _autorizaUsoImagen,
        autorizaDatoBiometrico: _autorizaDatoBiometrico,
        creadoEn: DateTime.now(),
      );

      await _almacenamiento.agregarRegistro(registro);

      if (!mounted) return;
      _mostrarMensaje('Guardado en el dispositivo. Se sincronizará cuando haya internet.');
      _limpiarFormulario();

      // Se intenta sincronizar de una vez por si ya hay conexión; si no la
      // hay, sincronizarPendientes() simplemente no hace nada (ver servicio).
      unawaited(_sincronizacion.sincronizarPendientes());
    } catch (e) {
      _mostrarMensaje('No se pudo guardar en el dispositivo: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState!.reset();
    _nombreCtrl.clear();
    _documentoCtrl.clear();
    setState(() {
      _autorizaUsoImagen = false;
      _autorizaDatoBiometrico = false;
      _rutaFotoTemporal = null;
    });
  }

  void _mostrarMensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subproyecto.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Ver registros guardados',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ListaRegistrosScreen()),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
              Card(
                 child: ListTile(
                   leading: const Icon(Icons.folder_outlined),
                   title: Text(widget.proyecto.nombre),
                   subtitle: Text(widget.subproyecto.nombre),
                 ),
               ),
              const SizedBox(height: 12),
            TextFormField(
              controller: _videoIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Identificador del video',
                helperText: 'Con esto el módulo de verificación facial sabe contra qué video comparar',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _documentoCtrl,
              decoration: const InputDecoration(labelText: 'Documento de identidad'),
              keyboardType: TextInputType.number,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 20),
            CapturaSelfieWidget(
              alCapturar: (ruta) => setState(() => _rutaFotoTemporal = ruta),
            ),
            const Divider(height: 32),
            CheckboxListTile(
              value: _autorizaUsoImagen,
              onChanged: (v) => setState(() => _autorizaUsoImagen = v ?? false),
              title: const Text('Autorizo el uso de mi imagen en este video/anuncio'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _autorizaDatoBiometrico,
              onChanged: (v) => setState(() => _autorizaDatoBiometrico = v ?? false),
              title: const Text('Autorizo el tratamiento de mi rostro como dato biométrico'),
              subtitle: const Text(
                'Dato sensible según la Ley 1581 de 2012. Existe una alternativa de '
                'registro no biométrica: verificación manual con el documento de '
                'identidad, sin usar reconocimiento facial.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
