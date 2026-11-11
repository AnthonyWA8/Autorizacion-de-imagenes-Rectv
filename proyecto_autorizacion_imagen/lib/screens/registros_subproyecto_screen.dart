import 'package:flutter/material.dart';

import '../models/proyecto.dart';
import '../services/proyectos_service.dart';

class RegistrosSubproyectoScreen extends StatefulWidget {
  const RegistrosSubproyectoScreen({
    super.key,
    required this.proyecto,
    required this.subproyecto,
  });

  final Proyecto proyecto;
  final Subproyecto subproyecto;

  @override
  State<RegistrosSubproyectoScreen> createState() =>
      _RegistrosSubproyectoScreenState();
}

class _RegistrosSubproyectoScreenState extends State<RegistrosSubproyectoScreen> {
  late final _stream =
      ProyectosService().registrosDeSubproyecto(widget.subproyecto.id);

  String _fecha(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.proyecto.nombre} · ${widget.subproyecto.nombre}'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar las firmas: ${snap.error}'),
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
                'Aún no hay firmas en este sub-proyecto.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = lista[i];
              final foto = r['fotoUrlRemota'] as String?;
              final biometrico = r['autorizaDatoBiometrico'] == true;
              return ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  backgroundImage: foto == null ? null : NetworkImage(foto),
                  onBackgroundImageError: foto == null ? null : (_, __) {},
                  child: foto == null ? const Icon(Icons.person) : null,
                ),
                title: Text(r['nombreCompleto'] as String? ?? ''),
                subtitle: Text(
                  'Doc. ${r['documentoIdentidad'] ?? ''}\n'
                  '${_fecha(r['creadoEn'] as String?)} · '
                  'Biométrico: ${biometrico ? 'Sí' : 'No'}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}