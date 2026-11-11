import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import 'lista_registros_screen.dart';
import 'proyectos_screen.dart';
import 'usuarios_screen.dart';

/// Panel de inicio: lo primero que ve el usuario después de iniciar sesión.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.usuario});

  final Usuario usuario;

  void _proximamente(BuildContext context, String nombre) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$nombre: próximamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().cerrarSesion(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hola, ${usuario.nombre}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(usuario.esAdmin ? Icons.shield : Icons.person, size: 18),
              label: Text(usuario.esAdmin ? 'Administrador' : 'Usuario'),
            ),
          ),
          const SizedBox(height: 16),
          _OpcionCard(
            icono: Icons.folder_open,
            titulo: 'Proyectos',
            subtitulo: 'Proyectos y subproyectos de grabación',
            onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProyectosScreen(usuario: usuario),
                  ),
                );
            },
          ),
          _OpcionCard(
            icono: Icons.list_alt,
            titulo: 'Registros guardados',
            subtitulo: 'Estado de sincronización',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ListaRegistrosScreen()),
            ),
          ),
          _OpcionCard(
            icono: Icons.face_retouching_natural,
            titulo: 'Reconocimiento facial',
            subtitulo: 'Disponible en una próxima versión',
            habilitada: false,
          ),
            if (usuario.esAdmin)
              _OpcionCard(
                icono: Icons.admin_panel_settings,
                titulo: 'Usuarios',
                subtitulo: 'Crear cuentas y asignar roles',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsuariosScreen()),
                ),
            ),
        ],
      ),
    );
  }
}

class _OpcionCard extends StatelessWidget {
  const _OpcionCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.onTap,
    this.habilitada = true,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;
  final bool habilitada;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        enabled: habilitada,
        leading: Icon(icono, size: 32),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: habilitada ? onTap : null,
      ),
    );
  }
}