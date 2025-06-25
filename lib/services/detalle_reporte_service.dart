import 'dart:convert';
import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:http/http.dart' as http;

class DetalleReporteService {
  final String baseUrl =
      'https://controlverdebackend.onrender.com/api/detallereportes';

  Future<List<Reporte>> obtenerProductosDeLaTim(int tim) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/productos/$tim'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        // Verificamos que realmente venga una lista
        if (jsonList.isNotEmpty) {
          return jsonList.map((json) => Reporte.fromJson(json)).toList();
        } else {
          print('Respuesta no es una lista');
          return [];
        }
      } else {
        print('Error de servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error al obtener productos: $e');
      return [];
    }
  }

  Future<List<Reporte>> detalleReportesInventario(String motivo, String ean) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        // Verificamos que realmente venga una lista
        if (jsonList.isNotEmpty) {
          return jsonList.map((json) => Reporte.fromJson(json)).toList();
        } else {
          print('Respuesta no es una lista');
          return [];
        }
      } else {
        print('Error de servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error al obtener detalles por sala: $e');
      return [];
    }
  }

  Future<bool> actualizarRecibidos(String id, double uRecibidas, String sala) async {
    final socketId = SocketService().socketId;

    final response = await http.post(
      Uri.parse('$baseUrl/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'uRecibidas': uRecibidas,
        'socketId': socketId,
        'salaId': sala,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Actualización exitosa');
      return true;
    } else {
      print('❌ Error al actualizar: ${response.body}');
      return false;
    }
  }

  Future<int> actualizarDatosDetalle(Reporte detalleReporte, String sala) async {
    final socketId = SocketService().socketId;

    final response = await http.post(
      Uri.parse('$baseUrl/updatedr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': detalleReporte.id,
        'uRecibidas': detalleReporte.uRecibidas,
        'fechavencimiento': detalleReporte.fechavencimiento,
        'socketId': socketId,
        'salaId': sala,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Actualización exitosa');
      return 1;
    } else {
      print('❌ Error al actualizar: ${response.body}');
      return 0;
    }
  }

  Future<Reporte> insertarDetalleReporte(DetalleReporte detalleReporte, String sala) async {
    final socketId = SocketService().socketId;
    final url = Uri.parse('$baseUrl/add');
    final body = {
      'detalleReporte': detalleReporte.toJson(),
      'socketId': socketId,
      'salaId': sala
    };
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final producto = data['resultado'];
      print(producto);
      final result = Reporte.fromJson(producto);
      print(result);
      return result;
    } else {
      throw Exception('Error al insertar detalle reporte: ${response.body}');
    }
  }

  Future<bool> crearDetalleReporteEnLote(List<Reporte> productos,
      {int chunkSize = 500, int maxRetries = 3}) async {
    final url = Uri.parse('$baseUrl/lote');
    final headers = {'Content-Type': 'application/json'};

    for (var i = 0; i < productos.length; i += chunkSize) {
      final chunk = productos.skip(i).take(chunkSize).toList();
      final body = jsonEncode(chunk.map((p) => p.toMap()).toList());

      int retryCount = 0;
      bool success = false;

      while (!success && retryCount < maxRetries) {
        final response = await http.post(url, headers: headers, body: body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          print('✅ Lote ${i ~/ chunkSize + 1} cargado con éxito');
          success = true;
        } else {
          retryCount++;
          print(
              '❌ Error al cargar lote ${i ~/ chunkSize + 1}, intento $retryCount');
          print('Código: ${response.statusCode}');
          print('Respuesta: ${response.body}');
          await Future.delayed(
              Duration(seconds: 2)); // espera antes de reintentar
        }
      }

      if (!success) {
        print(
            '🚫 Falló el lote ${i ~/ chunkSize + 1} después de $maxRetries intentos.');
        // Puedes seguir o retornar false si prefieres detener
      }
    }

    print('🎉 Todos los lotes fueron procesados');
    return true;
  }

  Future<bool> eliminarDetalleReporte(String id, String sala) async {
    final socketId = SocketService().socketId;
    final url = Uri.parse('$baseUrl/delete/$id');
    final body = {
      'socketId': socketId,
      'salaId': sala
    };
    final response = await http.delete(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      print('Error: ${response.body}');
      return false;
    }
  }
}
