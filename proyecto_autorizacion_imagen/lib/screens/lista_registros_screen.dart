import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/registro_autorizacion.dart';
import '../services/almacenamiento_local_service.dart';
import '../services/sincronizacion_service.dart';

/// Muestra lo que hay guardado en el dispositivo con su estado de
/// sincronización, y permite forzar "Sincronizar ahora" — el checkpoint
/// más importante del Módulo 3 es precisamente poder ver, sin adivinar,
/// qué quedó pendiente y por qué.
class ListaRegistrosScreen extends StatefulWidget {
  const ListaRegistrosScreen({super.key});

  @override
  State<ListaRegistrosScreen> createState() => _ListaRegistrosScreenState();
}

class _ListaRegistrosScreenState extends State<ListaRegistrosScreen> {
  final _almacenamiento = AlmacenamientoLocalService();
  final _sincronizacion = SincronizacionService();

  List<RegistroAutorizacion> _registros = [];
  bool _cargando = true;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final registros = await _almacenamiento.obtenerTodos();
    registros.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
    if (!mounted) return;
    setState(() {
      _registros = registros;
      _cargando = false;
    });
  }

  Future<void> _sincronizarAhora() async {
    setState(() => _sincronizando = true);
    final resultado = await _sincronizacion.sincronizarPendientes();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado.sincronizados == 0 && resultado.fallidos == 0
              ? 'Sin conexión, o nada pendiente por sincronizar'
              : '${resultado.sincronizados} sincronizados, ${resultado.fallidos} con error',
        ),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros guardados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sincronizando ? null : _sincronizarAhora,
        icon: _sincronizando
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync),
        label: const Text('Sincronizar ahora'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _registros.isEmpty
              ? const Center(child: Text('Todavía no hay registros guardados'))
              : ListView.builder(
                  itemCount: _registros.length,
                  itemBuilder: (context, i) => _tarjetaRegistro(_registros[i]),
                ),
    );
  }

  Widget _tarjetaRegistro(RegistroAutorizacion r) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: File(r.fotoLocalPath).existsSync()
              ? FileImage(File(r.fotoLocalPath))
              : null,
          child: File(r.fotoLocalPath).existsSync() ? null : const Icon(Icons.person),
        ),
        title: Text(r.nombreCompleto),
        subtitle: Text(
          '${r.evento} · ${DateFormat('d MMM yyyy, HH:mm', 'es').format(r.creadoEn)}'
          '${r.errorSync != null ? '\n${r.errorSync}' : ''}',
        ),
        isThreeLine: r.errorSync != null,
        trailing: _chipEstado(r.estadoSync),
      ),
    );
  }

  Widget _chipEstado(EstadoSync estado) {
    final (color, texto) = switch (estado) {
      EstadoSync.sincronizado => (Colors.green, 'Sincronizado'),
      EstadoSync.pendiente => (Colors.orange, 'Pendiente'),
      EstadoSync.error => (Colors.red, 'Error'),
    };
    return Chip(
      label: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
