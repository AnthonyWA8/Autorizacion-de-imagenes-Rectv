import 'package:flutter/material.dart';

import '../models/proyecto.dart';
import '../models/usuario.dart';
import '../services/proyectos_service.dart';
import 'proyecto_detalle_screen.dart';

class ProyectosScreen extends StatefulWidget {
  const ProyectosScreen({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen> {
  final _servicio = ProyectosService();   
  late final _proyectos = _servicio.proyectos();
  final _busquedaCtrl = TextEditingController();
  bool _buscando = false;
  String _filtro = '';

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _alternarBusqueda() {
    setState(() {
      _buscando = !_buscando;
      if (!_buscando) {
        _busquedaCtrl.clear();
        _filtro = '';
      }
    });
  }

  Future<void> _nuevoProyecto() async {
    final nombreCtrl = TextEditingController();
    final clienteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proyecto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre del proyecto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clienteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Cliente (opcional)'),
            ),
          ],
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
      _servicio.crearProyecto(
        nombre: nombre,
        cliente: clienteCtrl.text.trim(),
        creadoPor: widget.usuario.correo,
      );
    }
  }

    Future<void> _confirmarEliminar(Proyecto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar proyecto?'),
        content: Text(
          'Se eliminará "${p.nombre}" junto con todos sus sub-proyectos.\n\n'
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
    if (ok == true) _servicio.eliminarProyecto(p.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buscando
            ? TextField(
                controller: _busquedaCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar proyecto o cliente...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _filtro = v.trim().toLowerCase()),
              )
            : const Text('Proyectos'),
        actions: [
          IconButton(
            icon: Icon(_buscando ? Icons.close : Icons.search),
            tooltip: _buscando ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: _alternarBusqueda,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoProyecto,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo proyecto'),
      ),
      body: StreamBuilder<List<Proyecto>>(
        stream: _proyectos,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar los proyectos: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = snap.data!
              .where((p) =>
                  _filtro.isEmpty ||
                  p.nombre.toLowerCase().contains(_filtro) ||
                  p.cliente.toLowerCase().contains(_filtro))
              .toList();

          if (lista.isEmpty) {
            return Center(
              child: Text(
                _filtro.isEmpty
                    ? 'Aún no hay proyectos.\nCrea el primero con el botón de abajo.'
                    : 'Sin resultados para "$_filtro"',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = lista[i];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.nombre),
                subtitle: p.cliente.isEmpty ? null : Text(p.cliente),
                trailing: widget.usuario.esAdmin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Eliminar proyecto',
                            onPressed: () => _confirmarEliminar(p),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProyectoDetalleScreen(
                      proyecto: p,
                      usuario: widget.usuario,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}