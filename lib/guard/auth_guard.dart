import 'package:control_verde/screens/auth/login.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().hasSession(),
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
        return child;
      },
    );
  }
}
