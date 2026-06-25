import 'dart:convert';
import 'package:control_verde/database/config.dart';
import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/usuario_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/utils/http.dart';

class AuthService {
  final UserRepository _repo = UserRepository();
  final HttpService _httpService = HttpService();

  Future<String?> login({
    required String clave,
    String? dni,
    String? correo,
  }) async {
    final body = {
      if (dni != null) "dni": dni,
      if (correo != null) "correo": correo,
      "password": clave,
    };

    // Usando nuestro HttpService mejorado
    final respuesta = await _httpService.peticionPOST('/usuarios/login', body);

    if (respuesta.success) {
      final data = respuesta.datos;

      final usuario = Usuario(
        nombre: data["nombre"],
        rol: data["rol"],
        token: data["token"],
        dni: data["dni"],
        correo: data["correo"],
      );

      await _repo.saveUser(usuario);
      return null; // Nulo significa éxito de login sin errores 
    }

    // Retornamos el mensaje de error explícito (ej. "No hay conexión...", "Credenciales inválidas")
    return respuesta.mensaje;
  }

 Future<bool> hasSession() async {
  try {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      "app_user",
      limit: 1,
    );

    if (result.isEmpty) return false;

    final token = result.first["token"] as String?;
    return token != null && token.isNotEmpty;
  } catch (e) {
    return false;
  }
}

  Future<void> logout() => _repo.logout();
}
