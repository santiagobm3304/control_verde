import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/auth/login.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:flutter/material.dart';

class SesionHelper {
  static bool _isLoggingOut = false;

  static Future<void> cerrarSesion(
    BuildContext context, {
    String mensaje = "Tu sesión se ha cerrado. Por favor, inicia sesión nuevamente.",
  }) async {

    if (_isLoggingOut) return; // evita llamadas duplicadas
    _isLoggingOut = true;

    try {
      final repo = UserRepository();
      await repo.logout().catchError((e) {
        print("❌ Error en logout(): $e");
      });

      // Stop Sockets
      SocketService().dispose();

      if (!context.mounted) return;

      // Mostrar mensaje
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );

      // Redirigir al login (Root para cerrar diálogos)
      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 200)); 
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }

    } finally {
      _isLoggingOut = false;
    }
  }
}
