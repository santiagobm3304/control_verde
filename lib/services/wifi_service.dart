import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WifiService {
  Future<bool> checkInternetConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        print('✅ Conexión a Internet detectada');
        return true;
      } else {
        print('📴 Sin conexión a Internet');
        return false;
        
      }
    } catch (_) {
      print('📴 Sin conexión a Internet');
      return false;
    }
  }

}
