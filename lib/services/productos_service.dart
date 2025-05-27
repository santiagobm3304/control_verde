import 'dart:convert';
import 'package:control_verde/database/database_helper.dart';
import 'package:http/http.dart' as http;
import 'package:control_verde/model/producto_model.dart';

class ProductoService {
  final String baseUrl =
      'https://controlverdebackend.onrender.com/api/productos';

  Future<Producto?> obtenerProductoPorCodigo(String codigo) async {
    final url = Uri.parse('$baseUrl/buscar/$codigo');

    final response = await http.get(url);
    print('Respuesta: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Producto.fromJson(data['producto']);
    } else {
      print('Error: ${response.statusCode}');
      return null;
    }
  }

  Future<bool> crearProductosEnLote(List<Producto> productos,
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

  Future<Producto?> crearProducto(Producto producto) async {
    final url = Uri.parse('$baseUrl/agregar');
    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      'sku': producto.sku,
      'ean': producto.ean,
      'subdpto': producto.subdpto,
      'descripcion': producto.descripcion,
      'marca': producto.marca,
      'proveedor': producto.proveedor,
      'casePack': producto.casePack,
      'costoPromedio': producto.costoPromedio,
      'precioVigente': producto.precioVigente,
      'uMedida': producto.uMedida,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      print('Producto creado con éxito: ${producto.sku}');
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.actualizarCamposReporteDesdeProducto(
          producto.sku, producto);
      return producto;
    } else {
      print('Error al crear producto: ${response.statusCode}');
      print(response.body);
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchProductosPorSkus(Set<String> skus) async {
    final response = await http.post(
      Uri.parse('${baseUrl}/by-skus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'skus': skus.toList()}),
    );

    if (response.statusCode == 200) {
      final List productos = jsonDecode(response.body);
      return {
        for (var p in productos)
          p['sku']: {
            'ean': p['ean'],
            'costoPromedio': p['costoPromedio'],
            'precioVigente': p['precioVigente'],
            'uMedida': p['uMedida'],
          }
      };
    } else {
      throw Exception('Error al obtener productos del backend');
    }
  }
}
