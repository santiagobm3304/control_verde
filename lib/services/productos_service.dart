import 'package:control_verde/utils/session_helper.dart';
import 'package:flutter/material.dart';
import 'package:control_verde/utils/http.dart';
import 'package:control_verde/model/producto_model.dart';

class ProductoService {
  final httpService = HttpService();

  // ----------------------------------------------------------
  // Obtener producto por código (EAN o SKU)
  // ----------------------------------------------------------
  Future<Producto?> obtenerProductoPorCodigo(
    BuildContext context,
    String codigo,
  ) async {
    final endpoint = "/productos/buscar/$codigo";

    final res = await httpService.peticionGET(endpoint);

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return null;
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return null;
    }
    return Producto.fromJson(res.datos);
  }

  // ----------------------------------------------------------
  // Crear productos en lote
  // ----------------------------------------------------------
  Future<bool> crearProductosEnLote(
    BuildContext context,
    List<Producto> productos, {
    int chunkSize = 500,
  }) async {
    for (var i = 0; i < productos.length; i += chunkSize) {
      final chunk = productos.skip(i).take(chunkSize).toList();
      final chunkMap = chunk.map((p) => p.toMap()).toList();

      final res = await httpService
          .peticionPOST("/productos/lote", {"productos": chunkMap});

      if (res.status == 403) {
        await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
        return false;
      }

      if (!res.success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(res.mensaje)));
        return false;
      }

      print("Chunk cargado: ${i ~/ chunkSize + 1}");
    }

    print("Todos los lotes procesados");
    return true;
  }

  // ----------------------------------------------------------
  // Crear un producto individual
  // ----------------------------------------------------------
  Future<Producto?> crearProducto(
    BuildContext context,
    Producto producto,
  ) async {
    final body = {
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
    };

    final res = await httpService.peticionPOST("/productos/add", body);

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return null;
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return null;
    }

    return producto;
  }

  // ----------------------------------------------------------
  // Actualizar producto
  // ----------------------------------------------------------
  Future<bool> actualizarProducto(
    BuildContext context,
    Producto producto,
  ) async {
    final body = {
      'sku': producto.sku,
      'ean': producto.ean,
      'uMedida': producto.uMedida,
    };

    final res = await httpService.peticionPOST("/productos/updatep", body);

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return false;
    }

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar: ${res.mensaje}")),
      );
      return false;
    }

    return true;
  }

  // ----------------------------------------------------------
  // Obtener productos por muchos SKUs
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> fetchProductosPorSkus(
    BuildContext context,
    Set<String> skus,
  ) async {
    final res = await httpService.peticionPOST(
      "/productos/by-skus",
      {"skus": skus.toList()},
    );

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return {};
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return {};
    }

    final List productos = res.datos;

    return {
      for (var p in productos)
        p['sku']: {
          'ean': p['ean'],
          'costoPromedio': p['costoPromedio'],
          'precioVigente': p['precioVigente'],
          'uMedida': p['uMedida'],
        }
    };
  }

  // ----------------------------------------------------------
  // Obtener productos según subdepartamentos
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchProductosDesdeBackend(BuildContext context) async {
    final response = await httpService.peticionGET('/productos/por-subdptos');

    if (response.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: response.mensaje);
      return [];
    }

    if (response.status != 200 || response.datos == null) {
      throw Exception('Error al obtener productos');
    }

    // 👇 OJO AQUÍ
    final List data = response.datos as List;

    return data.cast<Map<String, dynamic>>();
  }
}
