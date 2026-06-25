import 'package:control_verde/database/config.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/utils/http.dart';
import 'package:control_verde/utils/session_helper.dart';
import 'package:flutter/material.dart';

class ReporteService {
  String get baseUrl => AppConfig.apiBaseUrl + '/reportes';
  final httpService = HttpService();

  // 🔥 Agregamos el BuildContext como parámetro
  Future<bool> crearReporte(
    BuildContext context,
    ReporteTim reporteTim,
  ) async {
    final url = Uri.parse('/reportes/add');

    final body = {
      'tim': reporteTim.tim,
      'placa': reporteTim.placa,
      'origen': reporteTim.localOrigen,
      'destino': reporteTim.localDestino,
      'fechaEnvio': reporteTim.fechaEnvio,
      'creadoPor': reporteTim.creadoPor,
      'estado': true,
      'motivo': reporteTim.motivo
    };

    final response = await httpService.peticionPOST(url.toString(), body);

    // 🔥 Manejo de sesión expirada
    if (response.status == 403) {
      await SesionHelper.cerrarSesion(
        context,
        mensaje: response.mensaje,
      );
      return false;
    }

    if (response.success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(response.mensaje)));
      return true;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(response.mensaje)));

    return false;
  }

  Future<List<int>> buscarPorMotivo(BuildContext context, String motivo) async {
  final uri = Uri.parse('/reportes/buscar?motivo=$motivo');
  final response = await httpService.peticionGET(uri.toString());

  if (response.status == 403) {
    await SesionHelper.cerrarSesion(context, mensaje: response.mensaje);
    return [];
  }

  if (response.success) {
    final List<dynamic> data = response.datos;
    return data.map((tim) => (tim as num).toInt()).toList();
  }

  throw Exception(response.mensaje);
}


  Future<ReporteTim?> obtenerReporte(
    BuildContext context,
    int tim,
  ) async {
    final url = Uri.parse('/reportes/reporte/$tim');

    final response = await httpService.peticionGET(url.toString());

    if (response.status == 403) {
      await SesionHelper.cerrarSesion(
        context,
        mensaje: response.mensaje,
      );
      return null;
    }

    if (response.success) {
      final data = ReporteTim.fromJson(response.datos);
      return data;
    }

    return null;
  }

  Future<bool> eliminarTim(
    BuildContext context,
    int tim,
  ) async {
    final url = Uri.parse('/reportes/deleterdr/$tim');

    final response = await httpService.peticionGET(url.toString());

    if (response.status == 403) {
      await SesionHelper.cerrarSesion(
        context,
        mensaje: response.mensaje,
      );
      return false;
    }

    return response.success;
  }
}
