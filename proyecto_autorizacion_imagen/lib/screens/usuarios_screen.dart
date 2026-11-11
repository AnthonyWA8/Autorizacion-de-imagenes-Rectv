import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/perfil_usuario.dart';
import '../services/usuarios_service.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _servicio = UsuariosService();
  late final _stream = _servicio.usuarios();
  final _miUid = FirebaseAuth.instance.currentUser?.uid;

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  String _errorAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Si quedó a medias, bórrala en '
            'la consola de Firebase (Authentication) y vuelve a crearla.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Error de autenticación: ${e.code}';
    }
  }

  Future<void> _nuevo() async {
    final datos = await showDialog<_DatosNuevo>(
      context: context,
      builder: (_) => const _NuevoUsuarioDialog(),
    );
    if (datos == null) return;

    _mensaje('Creando cuenta...');
    try {
      await _servicio.crearUsuario(
        nombre: datos.nombre,
        correo: datos.correo,
        contrasena: datos.contrasena,
        cargo: datos.cargo,
        esAdmin: datos.esAdmin,
      );
      _mensaje('Cuenta creada para ${datos.correo}');
    } on FirebaseAuthException catch (e) {
      _mensaje(_errorAuth(e));
    } on FirebaseException catch (e) {
      _mensaje('La cuenta se creó pero no se pudo guardar su perfil (${e.code}). '
          'Bórrala en la consola de Firebase (Authentication) e inténtalo de nuevo.');
    } on TimeoutException {
      _mensaje('Tardó demasiado. Revisa tu conexión y mira en Authentication '
          'si la cuenta quedó creada.');
    } catch (e) {
      _mensaje('No se pudo crear: $e');
    }
  }

  Future<bool> _confirmar(String titulo, String texto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      _mensaje(exito);
    } on TimeoutException {
      _mensaje('No se pudo confirmar el cambio (¿sin internet?). '
          'Se aplicará cuando vuelva la conexión.');
    } on FirebaseException catch (e) {
      _mensaje('No se pudo aplicar el cambio (${e.code}).');
    } catch (e) {
      _mensaje('Error: $e');
    }
  }

  Future<void> _accion(String accion, PerfilUsuario u) async {
    switch (accion) {
      case 'rol':
        final haceAdmin = !u.esAdmin;
        final ok = await _confirmar(
          haceAdmin ? '¿Hacer administrador?' : '¿Quitar permisos de admin?',
          haceAdmin
              ? '${u.nombre} podrá editar el formulario y eliminar proyectos, clientes y usuarios.'
              : '${u.nombre} pasará a ser usuario normal.',
        );
        if (ok) {
          await _ejecutar(
            () => _servicio.cambiarRol(u.uid, esAdmin: haceAdmin),
            'Rol actualizado',
          );
        }
      case 'activo':
        final desactiva = u.activo;
        final ok = await _confirmar(
          desactiva ? '¿Desactivar cuenta?' : '¿Reactivar cuenta?',
          desactiva
              ? '${u.nombre} no podrá entrar ni usar la app. Puedes reactivarla cuando quieras.'
              : '${u.nombre} podrá volver a entrar.',
        );
        if (ok) {
          await _ejecutar(
            () => _servicio.cambiarActivo(u.uid, activo: !desactiva),
            desactiva ? 'Cuenta desactivada' : 'Cuenta reactivada',
          );
        }
      case 'reset':
        await _ejecutar(
          () => _servicio.enviarRestablecimiento(u.correo),
          'Correo enviado a ${u.correo}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
      ),
      body: StreamBuilder<List<PerfilUsuario>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudieron cargar los usuarios: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = lista[i];
              final esYo = u.uid == _miUid;
              final detalle = [
                u.esAdmin ? 'Administrador' : 'Usuario',
                if (u.cargo.isNotEmpty) u.cargo,
                if (!u.activo) 'DESACTIVADO',
              ].join(' · ');

              return ListTile(
                isThreeLine: true,
                leading: CircleAvatar(
                  child: Icon(u.esAdmin ? Icons.shield : Icons.person),
                ),
                title: Text(
                  (u.nombre.isEmpty ? u.correo : u.nombre) + (esYo ? ' (tú)' : ''),
                  style: u.activo
                      ? null
                      : const TextStyle(decoration: TextDecoration.lineThrough),
                ),
                subtitle: Text('${u.correo}\n$detalle'),
                // Sobre uno mismo no se ofrecen acciones, para no quedarse
                // sin administrador por accidente.
                trailing: esYo
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (a) => _accion(a, u),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'rol',
                            child: Text(u.esAdmin
                                ? 'Quitar permisos de admin'
                                : 'Hacer administrador'),
                          ),
                          PopupMenuItem(
                            value: 'activo',
                            child: Text(u.activo ? 'Desactivar cuenta' : 'Reactivar cuenta'),
                          ),
                          const PopupMenuItem(
                            value: 'reset',
                            child: Text('Enviar correo para cambiar contraseña'),
                          ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DatosNuevo {
  _DatosNuevo({
    required this.nombre,
    required this.correo,
    required this.contrasena,
    required this.cargo,
    required this.esAdmin,
  });

  final String nombre;
  final String correo;
  final String contrasena;
  final String cargo;
  final bool esAdmin;
}

class _NuevoUsuarioDialog extends StatefulWidget {
  const _NuevoUsuarioDialog();

  @override
  State<_NuevoUsuarioDialog> createState() => _NuevoUsuarioDialogState();
}

class _NuevoUsuarioDialogState extends State<_NuevoUsuarioDialog> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _cargo = TextEditingController();
  bool _esAdmin = false;
  bool _verClave = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    _cargo.dispose();
    super.dispose();
  }

  void _crear() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _DatosNuevo(
        nombre: _nombre.text.trim(),
        correo: _correo.text.trim(),
        contrasena: _clave.text,
        cargo: _cargo.text.trim(),
        esAdmin: _esAdmin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo usuario'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Correo no válido' : null,
              ),
              TextFormField(
                controller: _clave,
                obscureText: !_verClave,
                decoration: InputDecoration(
                  labelText: 'Contraseña temporal',
                  helperText: 'Mínimo 6 caracteres',
                  suffixIcon: IconButton(
                    icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verClave = !_verClave),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              TextFormField(
                controller: _cargo,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Cargo (opcional)',
                  hintText: 'Camarógrafo, Director...',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _esAdmin,
                onChanged: (v) => setState(() => _esAdmin = v),
                title: const Text('Administrador'),
                subtitle: const Text(
                  'Además de recolectar firmas y crear proyectos, puede editar el '
                  'formulario y eliminar proyectos, clientes y usuarios.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _crear, child: const Text('Crear')),
      ],
    );
  }
}