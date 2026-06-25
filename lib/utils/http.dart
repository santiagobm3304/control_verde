import 'dart:convert';
import 'package:control_verde/database/config.dart';
import 'package:control_verde/model/respuesta_api.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:http/http.dart' as http;

class HttpService {
  final UserRepository _repo = UserRepository();

  /// GET
  Future<RespuestaApi<dynamic>> peticionGET(String endpoint) async {
    try {
      // 1️⃣ Obtener token
      final user = await _repo.getUser();
      final token = user?.token;

      print("Realizando petición GET a: ${AppConfig.apiBaseUrl}$endpoint");

      // 2️⃣ Hacer petición con token y timeout
      final res = await http.get(
        Uri.parse("${AppConfig.apiBaseUrl}$endpoint"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
      ).timeout(const Duration(seconds: 15));

      return _procesarRespuesta(res);
    } catch (e) {
      return _manejarExcepcion(e);
    }
  }

  /// POST
  Future<RespuestaApi<dynamic>> peticionPOST(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final user = await _repo.getUser();
      final token = user?.token;

      print("Realizando petición POST a: ${AppConfig.apiBaseUrl}$endpoint");

      final res = await http
          .post(
            Uri.parse("${AppConfig.apiBaseUrl}$endpoint"),
            headers: {
              "Content-Type": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      return _procesarRespuesta(res);
    } catch (e) {
      return _manejarExcepcion(e);
    }
  }

  /// Procesa la respuesta HTTP y extrae los datos del backend
  RespuestaApi<dynamic> _procesarRespuesta(http.Response res) {
    try {
      final body = jsonDecode(res.body);

      // 3️⃣ Formato que tu backend retorna
      // Soporta tanto boolean como strings (ej: ENUMS.SUCCESS/ERROR)
      final rawSuccess = body["success"];
      final bool success = (rawSuccess == true ||
          rawSuccess == 1 ||
          rawSuccess == "success" ||
          rawSuccess == "true" ||
          rawSuccess == "SUCCESS");
      String message = body["message"] ??
          body["mensaje"] ??
          "Sin mensaje descriptivo del servidor";
      final datos = body["datos"];

      message = _traducirMensajeBackend(message);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return RespuestaApi(
          success: success,
          mensaje: message,
          datos: datos,
          status: res.statusCode,
        );
      } else {
        // Manejar errores HTTP (400, 401, 500, etc.) pero que devuelven JSON
        return RespuestaApi(
          success: false,
          mensaje: message.isNotEmpty
              ? message
              : "Error del servidor (${res.statusCode})",
          datos: body["datos"],
          status: res.statusCode,
        );
      }
    } on FormatException catch (_) {
      // Si el servidor no devolvió JSON (ej. 502 Bad Gateway en HTML)
      return RespuestaApi(
        success: false,
        mensaje:
            "Error de formato en la respuesta del servidor (${res.statusCode}).",
        datos: null,
        status: res.statusCode,
      );
    }
  }

  /// Traduce los errores técnicos más comunes desde el backend a lenguaje humano
  String _traducirMensajeBackend(String originalMessage) {
    final lower = originalMessage.toLowerCase();

    if (lower.contains('jwt expired') || lower.contains('token expirado')) {
      return "Tu sesión ha expirado. Por favor, inicia sesión nuevamente.";
    }
    if (lower.contains('jwt malformed') ||
        lower.contains('invalid token') ||
        lower.contains('invalid signature')) {
      return "Credenciales de sesión inválidas. Inicia sesión nuevamente.";
    }
    if (lower.contains('not found')) {
      return "El recurso solicitado no fue encontrado.";
    }
    if (lower.contains('unauthorized')) {
      return "No tienes permiso para realizar esta acción.";
    }
    if (lower.contains('internal server error')) {
      return "Hubo un error interno en el servidor. Intenta más tarde.";
    }

    return originalMessage;
  }

  /// Maneja excepciones de Dart (Red, Tiempos de espera, etc.)
  RespuestaApi<dynamic> _manejarExcepcion(Object e) {
    String mensajeError =
        "Ocurrió un error inesperado. Por favor, intenta de nuevo.";

    if (e.toString().contains('SocketException')) {
      mensajeError =
          "No hay conexión a internet. Revisa tu conexión de red e intenta nuevamente.";
    } else if (e.toString().contains('TimeoutException')) {
      mensajeError =
          "La conexión ha tardado demasiado en responder. Intenta de nuevo más tarde.";
    } else if (e is FormatException) {
      mensajeError = "Hubo un problema procesando la información del servidor.";
    } else {
      mensajeError = "Error inesperado: ${e.toString()}";
    }

    return RespuestaApi(
      success: false,
      mensaje: mensajeError,
      datos: null,
      status: 405,
    );
  }

  Future<bool> validarstatus(String status) async {
    if (status != 403) return true;
    return false;
  }
}
