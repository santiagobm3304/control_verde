import 'package:control_verde/guard/auth_guard.dart';
import 'package:control_verde/inicio_screeen.dart';
import 'package:control_verde/utils/session_helper.dart';
import 'package:flutter/material.dart';

/// Navigator raíz de toda la app. SesionHelper lo usa para resetear la
/// navegación al login sin depender del BuildContext de quien dispare el
/// cierre de sesión (una pantalla, un diálogo, o un diálogo anidado dentro
/// de otro diálogo).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  SesionHelper.navigatorKey = appNavigatorKey;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'IControl',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: AuthGuard(
        child: InicioScreen(),  // Esta pantalla solo carga si hay sesión
      ),
    );
  }
}