import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/auth/login.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:flutter/material.dart';

class SesionHelper {
  static bool _isLoggingOut = false;

  /// Debe apuntar al MISMO GlobalKey<NavigatorState> que usa tu
  /// MaterialApp(navigatorKey: ...). Configúralo una sola vez en main.dart:
  ///
  ///   SesionHelper.navigatorKey = miNavigatorKeyGlobal;
  ///
  /// Con esto, cerrarSesion ya NO depende del BuildContext específico que
  /// lo dispare (una pantalla, un diálogo, o un diálogo anidado dentro de
  /// otro diálogo): siempre opera sobre el Navigator raíz real de la app,
  /// que nunca deja de existir mientras la app esté corriendo. Esto es lo
  /// que elimina de raíz los crashes de '_history.isNotEmpty' y los casos
  /// donde un diálogo queda "flotando" sobre el login.
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> cerrarSesion(
    BuildContext context, {
    String mensaje =
        "Tu sesión se ha cerrado. Por favor, inicia sesión nuevamente.",
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

      final navState = navigatorKey?.currentState;

      if (navState == null) {
        // Fallback defensivo por si navigatorKey no se configuró: se
        // comporta como antes, usando el context recibido. Mantiene la
        // app funcionando aunque falte el paso 2 de esta guía, pero sin
        // la protección completa contra el crash.
        print('⚠️ SesionHelper.navigatorKey no está configurado. '
            'Usando el context recibido como respaldo (ver session_helper.dart).');
        if (!context.mounted) return;
        _mostrarSnackYRedirigir(context, mensaje);
        return;
      }

      // Usamos el context del propio Navigator raíz para el snackbar y la
      // navegación, no el context que nos pasó quien llamó a
      // cerrarSesion (que puede ser un diálogo anidado a punto de
      // desaparecer).
      final rootContext = navigatorKey!.currentContext;
      if (rootContext != null && rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).clearSnackBars();
        ScaffoldMessenger.of(rootContext).showSnackBar(
          SnackBar(content: Text(mensaje)),
        );
      }

      await Future.delayed(const Duration(milliseconds: 200));

      navState.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      print('❌ Error en cerrarSesion(): $e');
    } finally {
      _isLoggingOut = false;
    }
  }

  static void _mostrarSnackYRedirigir(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }
}