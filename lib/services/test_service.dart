import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TestService {
  final String baseUrl =
      'https://controlverdebackend.onrender.com/api';

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
