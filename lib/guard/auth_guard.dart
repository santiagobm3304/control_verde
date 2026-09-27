import 'package:control_verde/screens/auth/login.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  late final Future<bool> _sessionFuture;

  @override
  void initState() {
    super.initState();
    // Se crea UNA sola vez por instancia de AuthGuard (no en cada build).
    // Antes, al vivir dentro de build(), cada rebuild de AuthGuard volvía
    // a llamar hasSession(), reiniciando el FutureBuilder a "esperando" y
    // pudiendo competir con la navegación que hace LoginPage justo después
    // de iniciar sesión.
    _sessionFuture = AuthService().hasSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        // ⏳ Mientras valida sesión
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ❌ Error al validar sesión
        if (snapshot.hasError) {
          return const LoginPage();
        }

        // ❌ Sin sesión
        if (!snapshot.hasData || snapshot.data == false) {
          return const LoginPage();
        }

        // ✅ Sesión válida
        return widget.child;
      },
    );
  }
}