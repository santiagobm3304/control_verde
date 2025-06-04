import 'dart:convert';
import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:http/http.dart' as http;

class ReporteService {
  final String baseUrl =
      'https://controlverdebackend.onrender.com/api/reportes';

  Future<ReporteTim?> crearReporte(ReporteTim reporteTim) async {
    final url = Uri.parse('$baseUrl/add');
    final headers = {'Content-Type': 'application/json'};

    final body = jsonEncode({
      'tim': reporteTim.tim,
      'placa': reporteTim.placa,
      'origen': reporteTim.localOrigen,
      'destino': reporteTim.localDestino,
      'fechaEnvio': reporteTim.fechaEnvio,
      'estado': true,
      'motivo': reporteTim.motivo
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      print('Reporte creado con éxito: ${reporteTim.tim}');
      return reporteTim;
    } else {
      print('Error al crear reporteTim: ${response.statusCode}');
      print(response.body);
      return null;
    }
  }

  Future<List<int>> buscarPorMotivo(String motivo) async {
    final uri = Uri.parse('$baseUrl/buscar?motivo=$motivo');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((tim) => (tim as num).toInt()).toList(); // 👈 cast seguro
    } else {
      throw Exception('Error al buscar reportes: ${response.statusCode}');
    }
  }

  Future<ReporteTim?> obtenerReporte(int tim) async {
    final url = Uri.parse('$baseUrl/reporte/$tim');

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ReporteTim.fromJson(data['reporte']);
    } else {
      print('Error: ${response.statusCode}');
      return null;
    }
  }

}
