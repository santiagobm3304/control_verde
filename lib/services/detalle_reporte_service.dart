import 'package:control_verde/utils/session_helper.dart';
import 'package:flutter/material.dart';
import 'package:control_verde/utils/http.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/respuesta_api.dart';
import 'package:control_verde/services/socket_service.dart';

class DetalleReporteService {
  final httpService = HttpService();

  // ------------------------------------------------------------
  // Obtener productos de la TIM
  // ------------------------------------------------------------
  Future<List<Reporte>> obtenerProductosDeLaTim(
    BuildContext context,
    int tim,
  ) async {
    final res =
        await httpService.peticionGET("/detallereportes/productos/$tim");

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return [];
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return [];
    }

    final List<dynamic> lista = res.datos;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.mensaje)));
    return lista.map((e) => Reporte.fromJson(e)).toList();
  }

  // ------------------------------------------------------------
  // Detalles por motivo + SKU/EAN
  // ------------------------------------------------------------
  Future<List<Reporte>> detalleReportesInventario(
    BuildContext context,
    String motivo,
    String ean,
  ) async {
    final res = await httpService
        .peticionGET("/detallereportes/skumotivo?motivo=$motivo&sku=$ean");

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return [];
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return [];
    }

    final List<dynamic> lista = res.datos;
    return lista.map((e) => Reporte.fromJson(e)).toList();
  }

  // ------------------------------------------------------------
  // Actualizar unidades recibidas
  // ------------------------------------------------------------
  Future<RespuestaApi<dynamic>> actualizarRecibidos(
    BuildContext context,
    String id,
    double uRecibidas,
    String nombre,
    String sala,
  ) async {
    final socketId = SocketService().socketId;

    final body = {
      "id": id,
      "uRecibidas": uRecibidas,
      "socketId": socketId,
      "modificadoPor": nombre,
      "salaId": sala
    };

    final res = await httpService.peticionPOST("/detallereportes/update", body);

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
    }

    return res;
  }

  // ------------------------------------------------------------
  // Actualizar datos del detalle (vencimiento, recibidos)
  // ------------------------------------------------------------
  Future<int> actualizarDatosDetalle(
    BuildContext context,
    Reporte reporte,
    String sala,
  ) async {
    final socketId = SocketService().socketId;

    final body = {
      "id": reporte.id,
      "uRecibidas": reporte.uRecibidas,
      "fechavencimiento": reporte.fechavencimiento,
      "modificadoPor": reporte.modificadoPor,
      "socketId": socketId,
      "salaId": sala
    };

    final res =
        await httpService.peticionPOST("/detallereportes/updatedr", body);

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return 0;
    }

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar: ${res.mensaje}")));
      return 0;
    }

    return 1;
  }

  // ------------------------------------------------------------
  // Insertar detalle de reporte
  // ------------------------------------------------------------
  Future<Reporte?> insertarDetalleReporte(
    BuildContext context,
    DetalleReporte detalle,
    String sala,
  ) async {
    final socketId = SocketService().socketId;

    final body = {
      "detalleReporte": detalle.toJson(),
      "socketId": socketId,
      "salaId": sala
    };

    final res = await httpService.peticionPOST("/detallereportes/add", body);

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return null;
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return null;
    }

    return Reporte.fromJson(res.datos);
  }

  // ------------------------------------------------------------
  // Crear detalle en lote
  // ------------------------------------------------------------
  Future<bool> crearDetalleReporteEnLote(
    BuildContext context,
    List<Reporte> productos, {
    int chunkSize = 300,
  }) async {
    for (var i = 0; i < productos.length; i += chunkSize) {
      final chunk = productos.skip(i).take(chunkSize).toList();
      final body = chunk.map((p) => p.toMap()).toList();

      final res = await httpService
          .peticionPOST("/detallereportes/lote", {"productos": body});

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

    return true;
  }

  // ------------------------------------------------------------
  // Eliminar un detalle de reporte
  // ------------------------------------------------------------
  Future<bool> eliminarDetalleReporte(
    BuildContext context,
    String id,
    String sala,
  ) async {
    final socketId = SocketService().socketId;

    final res = await httpService.peticionPOST(
      "/detallereportes/delete/$id",
      {"socketId": socketId, "salaId": sala},
    );

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
      return false;
    }

    if (!res.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.mensaje)));
      return false;
    }

    return true;
  }

  // ------------------------------------------------------------
  // Cambiar estado de edición (bloquear/desbloquear)
  // ------------------------------------------------------------
  Future<RespuestaApi<dynamic>> cambiarEstadoEdicion(
    BuildContext context,
    String id,
    bool isEditing,
    String salaId,
  ) async {
    final socketId = SocketService().socketId;

    final body = {
      "id": id,
      "isEditing": isEditing,
      "salaId": salaId,
      "socketId": socketId,
    };

    print('🌐 Enviando estado-edicion: $body');
    final res =
        await httpService.peticionPOST("/detallereportes/estado-edicion", body);
    print('📥 Respuesta estado-edicion: ${res.success} - ${res.mensaje}');

    if (res.status == 403) {
      await SesionHelper.cerrarSesion(context, mensaje: res.mensaje);
    }

    return res;
  }
}
