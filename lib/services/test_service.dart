import 'package:control_verde/database/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TestService {
    String get baseUrl => AppConfig.apiBaseUrl+ '/usuarios/login';


  Future<bool> conectarAlBackend(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ping'));

      if (response.statusCode == 200) {
       return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
