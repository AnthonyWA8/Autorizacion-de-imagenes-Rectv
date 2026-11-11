import 'package:flutter/material.dart';

import '../models/proyecto.dart';
import '../models/usuario.dart';
import '../services/proyectos_service.dart';
import 'formulario_screen.dart';
import 'registros_subproyecto_screen.dart';

class ProyectoDetalleScreen extends StatefulWidget {
  const ProyectoDetalleScreen({
    super.key,
    required this.proyecto,
    required this.usuario,
  });

  final Proyecto proyecto;
  final Usuario usuario;

  @override
  State<ProyectoDetalleScreen> createState() => _ProyectoDetalleScreenState();
}

class _ProyectoDetalleScreenState extends State<ProyectoDetalleScreen> {
  final _servicio = ProyectosService();
  late final _subproyectos = _servicio.subproyectos(widget.proyecto.id);
  late final _conteos = _servicio.conteoPorSubproyecto(widget.proyecto.id);

  Future<void> _nuevoSubproyecto() async {
    final nombreCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo sub-proyecto'),
        content: TextField(
          controller: nombreCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la grabación',
            hintText: 'Ej: Grabación diciembre',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    final nombre = nombreCtrl.text.trim();
    if (ok == true && nombre.isNotEmpty) {
      _servicio.crearSubproyecto(
        proyectoId: widget.proyecto.id,
        nombre: nombre,
        creadoPor: widget.usuario.correo,
      );
    }
  }

  Future<void> _confirmarEliminar(Subproyecto s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar sub-proyecto?'),
        content: Text(
          'Se eliminará "${s.nombre}".\n\n'
          'Las firmas ya recolectadas NO se borran: quedan guardadas en el '
          'registro general.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _servicio.eliminarSubproyecto(
        proyectoId: widget.proyecto.id,
        subproyectoId: s.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.proyecto.nombre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoSubproyecto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo sub-proyecto'),
      ),
      body: StreamBuilder<List<Subproyecto>>(
        stream: _subproyectos,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar los sub-proyectos: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
              child: Text(
                'Este proyecto aún no tiene sub-proyectos.\n'
                'Crea uno (por ejemplo, una grabación) para empezar a recolectar firmas.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return StreamBuilder<Map<String, int>>(
            stream: _conteos,
            builder: (context, snapConteo) {
              final conteos = snapConteo.data ?? const <String, int>{};

              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = lista[i];
                  final n = conteos[s.id] ?? 0;
                  return ListTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text(s.nombre),
                    subtitle: Text(
                      '$n ${n == 1 ? 'firma' : 'firmas'} · toca para recolectar',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.list_alt),
                          tooltip: 'Ver firmas',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RegistrosSubproyectoScreen(
                                proyecto: widget.proyecto,
                                subproyecto: s,
                              ),
                            ),
                          ),
                        ),
                        if (widget.usuario.esAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Eliminar sub-proyecto',
                            onPressed: () => _confirmarEliminar(s),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FormularioScreen(
                          proyecto: widget.proyecto,
                          subproyecto: s,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}