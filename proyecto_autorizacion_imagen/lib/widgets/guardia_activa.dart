import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GuardiaActiva extends StatelessWidget {
  const GuardiaActiva({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return child;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snap) {
        final desactivada = snap.data?.data()?['activo'] == false;
        if (!desactivada) return child;

        // Si tenía pantallas abiertas encima, se cierran para que se vea el aviso.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).popUntil((ruta) => ruta.isFirst);
          }
        });
        return const _CuentaDesactivada();
      },
    );
  }
}

class _CuentaDesactivada extends StatelessWidget {
  const _CuentaDesactivada();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64),
              const SizedBox(height: 16),
              Text(
                'Tu cuenta está desactivada',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Habla con el administrador para que la reactive.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}