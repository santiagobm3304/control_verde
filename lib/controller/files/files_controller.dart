import 'dart:io';
import 'dart:convert';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/utils/alerts.dart';
import 'package:control_verde/utils/loading_files.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FilesController {
  static final FilesController instance = FilesController._init();
  FilesController._init();

  Future<File?> _validateFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      print('❌ Error: El archivo no existe');
      return null;
    }
    return file;
  }

  Future<bool> handleFileSelection(
    BuildContext context,
    int caso, {
    int? tim,
    List<int>? reportesInfo,
  }) async {
    switch (caso) {
      case 0:
        if (tim == null) {
          Alerts.instance.showErrorDialog(
              context, 'Se requiere un TIM para este archivo.');
          return false;
        }
        await pickAndProcessFile(
          context,
          allowedExtensions: ['txt'],
          processFunction: (filePath) async {
            await processTextReport(filePath, tim);
          },
        );
        return true;

      case 1:
        await pickAndProcessFile(
          context,
          allowedExtensions: ['xlsx'],
          processFunction: processExcelReport,
        );
        return true;

      case 2:
        await pickAndProcessFile(
          context,
          allowedExtensions: ['csv'],
          processFunction: processCsvDepthFile,
        );
        return true;

      case 3:
        if (reportesInfo == null) {
          Alerts.instance.showErrorDialog(context,
              'Se requiere información de reportes para este archivo.');
          return false;
        }
        await pickAndProcessFile(
          context,
          allowedExtensions: ['xlsx'],
          processFunction: (filePath) async {
            await processExcelPallet(filePath, reportesInfo);
          },
        );
        return true;
      case 4:
        if (reportesInfo == null) {
          Alerts.instance.showErrorDialog(context,
              'Se requiere información de reportes para este archivo.');
          return false;
        }
        await pickAndProcessFile(
          context,
          allowedExtensions: ['xlsx'],
          processFunction: (filePath) async {
            await processExcelPallet(filePath, reportesInfo);
          },
        );
        return true;
      default:
        Alerts.instance.showErrorDialog(context, 'Caso no reconocido.');
        return false;
    }
  }

  Future<bool> pickAndProcessFile(
    BuildContext context, {
    required List<String> allowedExtensions,
    required Future<void> Function(String) processFunction,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null) {
      Alerts.instance
          .showWarningDialog(context, 'No se seleccionó ningún archivo.');
      return false;
    }

    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;
    final dialogContext =
        await loading.instance.showLoadingDialog(context, fileName);

    try {
      await processFunction(filePath);
      Navigator.pop(dialogContext);
      Alerts.instance
          .showSuccessDialog(context, 'Archivo procesado y datos guardados.');
      return true;
    } catch (e) {
      Navigator.pop(dialogContext);
      Alerts.instance.showErrorDialog(
          context, 'Ocurrió un problema al procesar el archivo: $e');
      return false;
    }
  }

  Future<bool> processTextReport(String filePath, int tim) async {
    try {
      final file = await _validateFile(filePath);
      if (file == null) return false;

      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        print('⚠️ Advertencia: El archivo de texto está vacío');
        return false;
      }

      final dbHelper = DatabaseHelper.instance;

      for (final line in lines) {
        final parts = line.split('\t');
        if (parts.length < 3) {
          print('⚠️ Línea inválida (esperado EAN, cantidad, OLPN): $line');
          return false;
        }

        final ean = parts[0].trim();
        final cantidad = double.tryParse(parts[1].trim()) ?? 0;
        final olpn = parts[2].trim();
        final producto = await DatabaseHelper.instance.getProductobyEan(ean);
        if (ean.isEmpty || olpn.isEmpty || cantidad <= 0) {
          print('⚠️ Datos incompletos o inválidos: $line');
          return false;
        }

        final reporte = Reporte(
          tim: tim,
          olpn: olpn,
          ean: ean,
          subdpto: producto?.subdpto ?? '',
          sku: producto?.sku ?? '',
          descripcion: producto?.descripcion ?? '',
          casePack: producto?.casePack ?? 1,
          uMedida: producto?.uMedida ?? '',
          costoPromedio: producto?.costoPromedio ?? 0,
          precioVigente: producto?.precioVigente ?? 0,
          uEnviadas: 0,
          cEnviadas: cantidad / _parseDouble(producto?.casePack ?? 1),
          uRecibidas: cantidad,
          fechavencimiento: '',
          faltantes: '',
          fastRegister: false,
        );

        await dbHelper.insertReport(reporte);
      }
      print('✅ Archivo de texto procesado exitosamente');
      return true;
    } catch (e) {
      print('❌ Error al procesar el archivo de texto: $e');
      return false;
    }
  }

  // Future<bool> processCsvDepthFile(String filePath) async {
  //   try {
  //     final file = await _validateFile(filePath);
  //     if (file == null) return false;
  //     final data = await file.readAsString(encoding: latin1);
  //     List<List<dynamic>> rows =
  //         const CsvToListConverter(fieldDelimiter: ';').convert(data);
  //     // final dbHelper = DatabaseHelper.instance;
  //     final service = ProductoService();

  //     for (var i = 1; i < rows.length; i++) {
  //       var row = rows[i];

  //       final producto = Producto(
  //         subdpto: row[0].toString(),
  //         proveedor: row[1].toString(),
  //         ean: row[2].toString(),
  //         sku: row[3].toString(),
  //         descripcion: row[4].toString(),
  //         marca: row[5].toString(),
  //         costoPromedio: double.tryParse(row[6]?.toString() ?? '') ?? 0.0,
  //         precioVigente: double.tryParse(row[7]?.toString() ?? '') ?? 0.0,
  //         casePack: int.tryParse(row[8]?.toString() ?? '') ?? 1,
  //         uMedida: row[9].toString().trim(),
  //       );
  //       // await dbHelper.insertProducto(producto);
  //       await service.crearProductosEnLote(producto);
  //     }
  //     return true;
  //   } catch (e) {
  //     print("Error al procesar el archivo CSV: $e");
  //     return false;
  //   }
  // }
  Future<bool> processCsvDepthFile(String filePath) async {
    try {
      final file = await _validateFile(filePath);
      if (file == null) return false;

      final data = await file.readAsString(encoding: latin1);
      List<List<dynamic>> rows =
          const CsvToListConverter(fieldDelimiter: ';').convert(data);

      final service = ProductoService();
      final List<Producto> productos = [];

      for (var i = 1; i < rows.length; i++) {
        var row = rows[i];

        final producto = Producto(
          subdpto: row[0].toString(),
          proveedor: row[1].toString(),
          ean: row[2].toString(),
          sku: row[3].toString(),
          descripcion: row[4].toString(),
          marca: row[5].toString(),
          costoPromedio: double.tryParse(row[6]?.toString() ?? '') ?? 0.0,
          precioVigente: double.tryParse(row[7]?.toString() ?? '') ?? 0.0,
          casePack: int.tryParse(row[8]?.toString() ?? '') ?? 1,
          uMedida: row[9].toString().trim(),
        );

        productos.add(producto);

        // Enviar lote de 100
        if (productos.length == 100) {
          final ok = await service.crearProductosEnLote(productos);
          if (!ok) return false; // ❗ Detener si falla
          productos.clear();
        }
      }

      // Enviar el último lote si hay sobrantes
      if (productos.isNotEmpty) {
        final ok = await service.crearProductosEnLote(productos);
        if (!ok) return false; // ❗ Detener si falla
      }

      return true;
    } catch (e) {
      print("❌ Error al procesar el archivo CSV: $e");
      return false;
    }
  }

  String extractValue(String? input) {
    if (input == null || !input.contains(':')) return input ?? '';
    return input.split(':').skip(1).join(':').trim();
  }

  int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  // 🔹 Función auxiliar para convertir valores en double
  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  Future<void> processExcelReport(String filePath) async {
    try {
      final file = await _validateFile(filePath);
      if (file == null) return;

      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final dbHelper = DatabaseHelper.instance;

      if (!excel.tables.containsKey('Página1_1')) {
        print(
            '❌ Error: No se encontró la hoja "Página1_1" en el archivo Excel');
        return;
      }

      final sheet = excel.tables['Página1_1']!;
      if (sheet.rows.length < 10) {
        print(
            '⚠️ Advertencia: La hoja no tiene suficientes filas para procesar');
        return;
      }

      // 🔹 Crear el objeto ReporteTim y guardarlo en la BD
      final reporteTim = ReporteTim(
        tim: int.tryParse(extractValue(sheet.rows[3][0]?.value?.toString())) ??
            0,
        placa: extractValue(sheet.rows[5][0]?.value?.toString()),
        localOrigen: extractValue(sheet.rows[6][0]?.value?.toString()),
        localDestino: extractValue(sheet.rows[7][0]?.value?.toString()),
        fechaEnvio: extractValue(sheet.rows[8][0]?.value?.toString()),
        motivo: 'T',
      );

      await dbHelper.insertReporteTim(reporteTim);

      // 🔁 Consolidar los reportes por SKU antes de insertarlos
      final Set<String> skusUnicos = {};
      for (var i = 11; i < sheet.rows.length; i++) {
        final sku = sheet.rows[i][5]?.value?.toString() ?? '';
        if (sku.isNotEmpty) skusUnicos.add(sku);
      }
      final service = ProductoService();
      final productosMap = await service.fetchProductosPorSkus(skusUnicos);

      final Map<String, Reporte> consolidadoPorSku = {};

      for (var i = 11; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final sku = row[5]?.value?.toString() ?? '';
        if (sku.isEmpty) continue;

        final producto = productosMap[sku];

        final reporte = Reporte(
          tim: reporteTim.tim,
          olpn: row[0]?.value?.toString() ?? '',
          ean: producto?['ean'] ?? '',
          subdpto: row[4]?.value?.toString() ?? '',
          sku: sku,
          descripcion: row[6]?.value?.toString() ?? '',
          casePack: _parseInt(row[7]?.value),
          uMedida: producto?['uMedida'] ?? '',
          costoPromedio: (producto?['costoPromedio'] ?? 0).toDouble(),
          precioVigente: (producto?['precioVigente'] ?? 0).toDouble(),
          uEnviadas: _parseDouble(
            row[10]?.value != null &&
                    row[10]!.value.toString().trim().isNotEmpty
                ? row[10]!.value
                : row[8]?.value,
          ),
          cEnviadas: _parseDouble(row[9]?.value),
          uRecibidas: 0.0,
          fechavencimiento: '',
          faltantes: '',
          fastRegister: false,
        );

        if (consolidadoPorSku.containsKey(sku)) {
          final existente = consolidadoPorSku[sku]!;
          existente.uEnviadas += reporte.uEnviadas;
          existente.cEnviadas += reporte.cEnviadas;
        } else {
          consolidadoPorSku[sku] = reporte;
        }
      }

      for (final reporte in consolidadoPorSku.values) {
        await dbHelper.insertReport(reporte);
      }
    } catch (e) {
      print('❌ Error al procesar el archivo: $e');
    }
  }

  // Future<void> processExcelReport(String filePath) async {
  //   try {
  //     final file = await _validateFile(filePath);
  //     if (file == null) return;

  //     final bytes = file.readAsBytesSync();
  //     final excel = Excel.decodeBytes(bytes);
  //     final dbHelper = DatabaseHelper.instance;

  //     if (!excel.tables.containsKey('Página1_1')) {
  //       print(
  //           '❌ Error: No se encontró la hoja "Página1_1" en el archivo Excel');
  //       return;
  //     }

  //     final sheet = excel.tables['Página1_1']!;
  //     if (sheet.rows.length < 10) {
  //       print(
  //           '⚠️ Advertencia: La hoja no tiene suficientes filas para procesar');
  //       return;
  //     }

  //     // 🔹 Crear el objeto ReporteTim y guardarlo en la BD
  //     final reporteTim = ReporteTim(
  //       tim: int.tryParse(extractValue(sheet.rows[3][0]?.value?.toString())) ??
  //           0,
  //       placa: extractValue(sheet.rows[5][0]?.value?.toString()),
  //       localOrigen: extractValue(sheet.rows[6][0]?.value?.toString()),
  //       localDestino: extractValue(sheet.rows[7][0]?.value?.toString()),
  //       fechaEnvio: extractValue(sheet.rows[8][0]?.value?.toString()),
  //       motivo: 'T',
  //     );

  //     await dbHelper.insertReporteTim(reporteTim);

  //     // 🔁 Consolidar los reportes por SKU antes de insertarlos
  //     final Map<String, Reporte> consolidadoPorSku = {};

  //     for (var i = 11; i < sheet.rows.length; i++) {
  //       final row = sheet.rows[i];

  //       final sku = row[5]?.value?.toString() ?? '';
  //       if (sku.isEmpty) continue;

  //       final uEnviadas = _parseDouble(
  //         row[10]?.value != null && row[10]!.value.toString().trim().isNotEmpty
  //             ? row[10]!.value
  //             : row[8]?.value,
  //       );

  //       final reporte = Reporte(
  //         tim: reporteTim.tim,
  //         olpn: row[0]?.value?.toString() ?? '',
  //         ean: '',
  //         subdpto: row[4]?.value?.toString() ?? '',
  //         sku: sku,
  //         descripcion: row[6]?.value?.toString() ?? '',
  //         casePack: _parseInt(row[7]?.value),
  //         uMedida: '',
  //         costoPromedio: 0,
  //         precioVigente: 0,
  //         uEnviadas: uEnviadas,
  //         cEnviadas: _parseDouble(row[9]?.value),
  //         uRecibidas: 0.0,
  //         fechavencimiento: '',
  //         faltantes: '',
  //         fastRegister: false,
  //       );

  //       if (consolidadoPorSku.containsKey(sku)) {
  //         final existente = consolidadoPorSku[sku]!;
  //         existente.uEnviadas += reporte.uEnviadas;
  //         existente.cEnviadas += reporte.cEnviadas;
  //       } else {
  //         consolidadoPorSku[sku] = reporte;
  //       }
  //     }

  //     for (final reporte in consolidadoPorSku.values) {
  //       await dbHelper.insertReport(reporte);
  //     }
  //   } catch (e) {
  //     print('❌ Error al procesar el archivo: $e');
  //   }
  // }

  Future<bool> processExcelPallet(
      String filePath, List<int> ReportesInfo) async {
    try {
      final file = await _validateFile(filePath);
      if (file == null) return false;

      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);
      final dbHelper = DatabaseHelper.instance;

      if (!excel.tables.containsKey('Sheet1')) {
        print('❌ Error: No se encontró la hoja "Sheet1" en el archivo Excel');
        return false;
      }

      final sheet = excel.tables['Sheet1']!;
      if (sheet.rows.length < 5) {
        print(
            '⚠️ Advertencia: La hoja no tiene suficientes filas para procesar');
        return false;
      }

      final tim =
          int.tryParse(extractValue(sheet.rows[1][1]?.value?.toString())) ?? 0;

      if (ReportesInfo.contains(tim)) {
        print('❌ Error: El TIM ya existe en la base de datos.');
        return false;
      }
      final reporteTim = ReporteTim(
        tim: int.tryParse(extractValue(sheet.rows[1][1]?.value?.toString())) ??
            0,
        placa: 'Inventario',
        localOrigen: extractValue(sheet.rows[2][1]?.value?.toString()),
        localDestino: 'Inventario',
        fechaEnvio: extractValue(sheet.rows[3][1]?.value?.toString()),
        motivo: 'I',
      );

      for (var i = 6; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];

        final ean = row[2]?.value?.toString() ?? '';
        if (ean.isEmpty) continue;

        final reporte = Reporte(
          tim: reporteTim.tim,
          olpn: row[1]?.value?.toString() ?? '',
          ean: ean,
          subdpto: row[8]?.value?.toString() ?? '',
          sku: row[3]?.value?.toString() ?? '',
          descripcion: row[4]?.value?.toString() ?? '',
          casePack: _parseInt(row[9]?.value),
          uMedida: '',
          costoPromedio: _parseDouble(row[6]?.value),
          precioVigente: 0,
          uEnviadas: 0,
          cEnviadas: _parseDouble(row[5]?.value) / _parseInt(row[9]?.value),
          uRecibidas: _parseDouble(row[5]?.value),
          fechavencimiento: row[10]?.value?.toString() ?? '',
          faltantes: '',
          fastRegister: false,
        );
        await dbHelper.insertReport(reporte);
      }
      await dbHelper.insertReporteTim(reporteTim);
      return true;
    } catch (e, stackTrace) {
      print('❌ Error al procesar el archivo: $stackTrace');
      return false;
    }
  }
}
