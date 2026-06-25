import 'package:control_verde/inicio_screeen.dart';
import 'package:control_verde/services/auth_service.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:flutter/material.dart';

import '../../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool usarDni = true;

  final txtDni = TextEditingController();
  final txtCorreo = TextEditingController();
  final txtClave = TextEditingController();

  final auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LOGO / TÍTULO
                Icon(Icons.lock_outline, size: 70, color: AppColors.primary),
                const SizedBox(height: 10),
                Text(
                  "Iniciar Sesión",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 24),

                // TOGGLE
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  fillColor: AppColors.primary,
                  selectedColor: Colors.white,
                  color: AppColors.primaryDark,
                  borderColor: AppColors.primary,
                  selectedBorderColor: AppColors.primaryDark,
                  isSelected: [usarDni, !usarDni],
                  onPressed: (i) {
                    setState(() => usarDni = i == 0);
                  },
                  children: const [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Text("DNI"),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Text("Correo"),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // INPUT DNI o CORREO
                usarDni
                    ? _input("DNI", txtDni, Icons.badge)
                    : _input("Correo", txtCorreo, Icons.email),

                const SizedBox(height: 20),
                _input("Clave", txtClave, Icons.lock, isPassword: true),
                const SizedBox(height: 28),

                // BOTÓN LOGIN
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      // Opcional: Mostrar indicador de carga puede agergarse aquí.
                      final errorMessage = await auth.login(
                        clave: txtClave.text,
                        dni: usarDni ? txtDni.text : null,
                        correo: usarDni ? null : txtCorreo.text,
                      );

                      if (errorMessage == null) {
                        // 🔁 Fuerza rebuild para que AuthGuard reevalúe la sesión
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const MyApp(), // o raíz
                          ),
                          (_) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.redAccent,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      "Ingresar",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, IconData icon,
      {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
