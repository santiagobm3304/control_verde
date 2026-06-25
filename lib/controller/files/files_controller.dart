// import 'dart:io';
// import 'dart:convert';

// import 'package:control_verde/database/database_helper.dart';
// import 'package:control_verde/model/producto_model.dart';
// import 'package:control_verde/model/reporteTim_model.dart';
// import 'package:control_verde/model/reporte_model.dart';
// import 'package:control_verde/repository/user_repository.dart';
// import 'package:control_verde/services/detalle_reporte_service.dart';
// import 'package:control_verde/services/productos_service.dart';
// import 'package:control_verde/services/reporte_service.dart';
// import 'package:control_verde/utils/alerts.dart';
// import 'package:control_verde/utils/loading.dart';
// import 'package:csv/csv.dart';
// import 'package:excel/excel.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';

// class FilesController {
//   static final FilesController instance = FilesController._init();
//   FilesController._init();
//   final Alertas = Alerts.instance;
//   UserRepository _userRepo = UserRepository();

//   Future<File?> _validateFile(String path) async {
//     final file = File(path);
//     if (!file.existsSync()) {
//       print('❌ Error: El archivo no existe');
//       return null;
//     }
//     return file;
//   }

//   Future<bool> handleFileSelection(
//     BuildContext context,
//     int caso, {
//     int? tim,
//     List<int>? reportesInfo,
//   }) async {
//     switch (caso) {
//       case 0:
//         if (tim == null) {
//           Alerts.instance.showErrorDialog(
//               context, 'Se requiere un TIM para este archivo.');
//           return false;
//         }
//         // await pickAndProcessFile(
//         //   context,
//         //   allowedExtensions: ['txt'],
//         //   processFunction: (filePath) async {
//         //     return await processTextReport(filePath, tim);
//         //   },
//         // );
//         return true;

//       case 1:
//         await pickAndProcessFile(
//           context,
//           [],
//           allowedExtensions: ['xlsx'],
//           processFunction: processExcelReport,
//         );
//         return true;

//       case 2:
//         await pickAndProcessFile(
//           context,
//           [],
//           allowedExtensions: ['csv'],
//           processFunction: processCsvDepthFile,
//         );
//         return true;

//       case 3:
//         if (reportesInfo == null) {
//           Alertas.showErrorDialog(context,
//               'Se requiere información de reportes para este archivo.');
//           return false;
//         }
//         await pickAndProcessFile(
//           context,
//           reportesInfo,
//           allowedExtensions: ['xlsx'],
//           processFunction: processExcelPallet,
//         );
//         return true;
//       case 4:
//         if (reportesInfo == null) {
//           Alerts.instance.showErrorDialog(context,
//               'Se requiere información de reportes para este archivo.');
//           return false;
//         }
//         await pickAndProcessFile(
//           context,
//           reportesInfo,
//           allowedExtensions: ['xlsx'],
//           processFunction: processExcelPallet,
//         );
//         return true;
//       default:
//         Alerts.instance.showErrorDialog(context, 'Caso no reconocido.');
//         return false;
//     }
//   }

//   Future<bool> pickAndProcessFile(
//     BuildContext context,
//     List<int> reportesInfo, {
//     required List<String> allowedExtensions,
//     required Future<int> Function(BuildContext, String, List<int>)
//         processFunction,
//   }) async {
//     final result = await FilePicker.platform.pickFiles(
//       type: FileType.custom,
//       allowedExtensions: allowedExtensions,
//     );

//     if (result == null) {
//       Alerts.instance
//           .showWarningDialog(context, 'No se seleccionó ningún archivo.');
//       return false;
//     }

//     final filePath = result.files.single.path!;
//     final fileName = result.files.single.name;
//     final dialogContext =
//         await loading.instance.showLoadingDialog(context, fileName);

//     try {
//       final respuesta = await processFunction(context, filePath, reportesInfo);
//       Navigator.pop(dialogContext);
//       if (respuesta == 1) {
//         Alertas.showSuccessDialog(
//             context, 'Archivo procesado y datos guardados.');
//         return true;
//       } else {
//         Alertas.showWarningDialog(
//             context, 'El reporte no contiene datos válidos o ya existe.');
//         return false;
//       }
//     } catch (e) {
//       Navigator.pop(dialogContext);
//       Alertas.showErrorDialog(
//           context, 'Ocurrió un problema al procesar el archivo: $e');
//       return false;
//     }
//   }

//   // Future<int> processTextReport(String filePath, int tim) async {
//   //   try {
//   //     final file = await _validateFile(filePath);
//   //     if (file == null) return 0;

//   //     final lines = await file.readAsLines();
//   //     if (lines.isEmpty) {
//   //       print('⚠️ Advertencia: El archivo de texto está vacío');
//   //       return 0;
//   //     }

//   //     final dbHelper = DatabaseHelper.instance;

//   //     for (final line in lines) {
//   //       final parts = line.split('\t');
//   //       if (parts.length < 3) {
//   //         print('⚠️ Línea inválida (esperado EAN, cantidad, OLPN): $line');
//   //         return 0;
//   //       }

//   //       final ean = parts[0].trim();
//   //       final cantidad = double.tryParse(parts[1].trim()) ?? 0;
//   //       final olpn = parts[2].trim();
//   //       final producto = await dbHelper.getProductobyEan(ean);
//   //       if (ean.isEmpty || olpn.isEmpty || cantidad <= 0) {
//   //         print('⚠️ Datos incompletos o inválidos: $line');
//   //         return 0;
//   //       }

//   //       final reporte = Reporte(
//   //         id: '',
//   //         tim: tim,
//   //         olpn: olpn,
//   //         ean: ean,
//   //         subdpto: producto?.subdpto ?? '',
//   //         sku: producto?.sku ?? '',
//   //         descripcion: producto?.descripcion ?? '',
//   //         casePack: producto?.casePack ?? 1,
//   //         uMedida: producto?.uMedida ?? '',
//   //         costoPromedio: producto?.costoPromedio ?? 0,
//   //         precioVigente: producto?.precioVigente ?? 0,
//   //         uEnviadas: 0,
//   //         uRecibidas: cantidad,
//   //         fechavencimiento: '',
//   //         observacion: '',
//   //         fastRegister: false,
//   //       );

//   //       await dbHelper.insertReport(reporte);
//   //     }

//   //     print('✅ Archivo de texto procesado exitosamente');
//   //     return 1;
//   //   } catch (e) {
//   //     print('❌ Error al procesar el archivo de texto: $e');
//   //     return 0;
//   //   }
//   // }

//   // Future<bool> processCsvDepthFile(String filePath) async {
//   //   try {
//   //     final file = await _validateFile(filePath);
//   //     if (file == null) return false;
//   //     final data = await file.readAsString(encoding: latin1);
//   //     List<List<dynamic>> rows =
//   //         const CsvToListConverter(fieldDelimiter: ';').convert(data);
//   //     // final dbHelper = DatabaseHelper.instance;
//   //     final service = ProductoService();

//   //     for (var i = 1; i < rows.length; i++) {
//   //       var row = rows[i];

//   //       final producto = Producto(
//   //         subdpto: row[0].toString(),
//   //         proveedor: row[1].toString(),
//   //         ean: row[2].toString(),
//   //         sku: row[3].toString(),
//   //         descripcion: row[4].toString(),
//   //         marca: row[5].toString(),
//   //         costoPromedio: double.tryParse(row[6]?.toString() ?? '') ?? 0.0,
//   //         precioVigente: double.tryParse(row[7]?.toString() ?? '') ?? 0.0,
//   //         casePack: int.tryParse(row[8]?.toString() ?? '') ?? 1,
//   //         uMedida: row[9].toString().trim(),
//   //       );
//   //       // await dbHelper.insertProducto(producto);
//   //       await service.crearProductosEnLote(producto);
//   //     }
//   //     return true;
//   //   } catch (e) {
//   //     print("Error al procesar el archivo CSV: $e");
//   //     return false;
//   //   }
//   // }
//   Future<int> processCsvDepthFile(
//       BuildContext context, String filePath, List<int> ReportesInfo) async {
//     try {
//       final file = await _validateFile(filePath);
//       if (file == null) return 0;

//       final data = await file.readAsString(encoding: latin1);
//       List<List<dynamic>> rows =
//           const CsvToListConverter(fieldDelimiter: ';').convert(data);

//       final service = ProductoService();
//       final List<Producto> productos = [];

//       for (var i = 1; i < rows.length; i++) {
//         var row = rows[i];

//         final producto = Producto(
//           subdpto: row[0].toString(),
//           proveedor: row[1].toString(),
//           ean: row[2].toString(),
//           sku: row[3].toString(),
//           descripcion: row[4].toString(),
//           marca: row[5].toString(),
//           costoPromedio: double.tryParse(row[6]?.toString() ?? '') ?? 0.0,
//           precioVigente: double.tryParse(row[7]?.toString() ?? '') ?? 0.0,
//           casePack: int.tryParse(row[8]?.toString() ?? '') ?? 1,
//           uMedida: row[9].toString().trim(),
//           isContable: false,
//           marcaSensible: false,
//         );

//         productos.add(producto);

//         // Enviar lote de 100
//         if (productos.length == 100) {
//           final ok = await service.crearProductosEnLote(context, productos);
//           if (!ok) return 0; // ❗ Detener si falla
//           productos.clear();
//         }
//       }

//       // Enviar el último lote si hay sobrantes
//       if (productos.isNotEmpty) {
//         final ok = await service.crearProductosEnLote(context, productos);
//         if (!ok) return 0; // ❗ Detener si falla
//       }

//       return 1;
//     } catch (e) {
//       print("❌ Error al procesar el archivo CSV: $e");
//       return 0;
//     }
//   }

//   Future<int> processExcelReport(
//       BuildContext context, String filePath, List<int> ReportesInfo) async {
//     try {
//       final file = await _validateFile(filePath);
//       if (file == null) return 0;

//       final bytes = file.readAsBytesSync();
//       final excel = Excel.decodeBytes(bytes);
//       final serviceR = ReporteService();
//       final serviceD = DetalleReporteService();

//       if (!excel.tables.containsKey('Página1_1')) {
//         print('❌ Error: No se encontró la hoja "Página1_1"');
//         return 0;
//       }

//       final sheet = excel.tables['Página1_1']!;
//       if (sheet.rows.length < 10) {
//         print('⚠️ La hoja tiene menos de 10 filas');
//         return 0;
//       }
//       final nombre = await _userRepo.getNombreUsuario();
//       final reporteTim = ReporteTim(
//         tim: int.tryParse(extractValue(sheet.rows[3][0]?.value?.toString())) ??
//             0,
//         placa: extractValue(sheet.rows[5][0]?.value?.toString()),
//         localOrigen: extractValue(sheet.rows[6][0]?.value?.toString()),
//         localDestino: extractValue(sheet.rows[7][0]?.value?.toString()),
//         fechaEnvio: extractValue(sheet.rows[8][0]?.value?.toString()),
//         creadoPor: nombre,
//         motivo: 'T',
//       );
//       // Crear ReporteTim en backend
//       final reporte = await serviceR.crearReporte(context, reporteTim);
//       if (reporte == null) {
//         print('❌ Error: El TIM ya existe en la base de datos.');
//         return 0;
//       }

//       final List<Reporte> loteReporte = [];
//       const int loteSize = 100;

//       for (var i = 11; i < sheet.rows.length; i++) {
//         final row = sheet.rows[i];
//         final sku = row[5]?.value?.toString().trim() ?? '';
//         if (sku.isEmpty) continue;

//         final reporte = Reporte(
//           id: '',
//           tim: reporteTim.tim,
//           olpn: row[0]?.value?.toString() ?? '',
//           ean: '',
//           subdpto: row[4]?.value?.toString() ?? '',
//           sku: sku,
//           descripcion: row[6]?.value?.toString() ?? '',
//           casePack: _parseInt(row[7]?.value),
//           uMedida: '',
//           costoPromedio: 0.0,
//           precioVigente: 0.0,
//           uEnviadas: _parseDouble(
//             row[10]?.value != null &&
//                     row[10]!.value.toString().trim().isNotEmpty
//                 ? row[10]!.value
//                 : row[8]?.value,
//           ),
//           uRecibidas: 0.0,
//           fechavencimiento: '',
//           observacion: 'PERTENECE',
//           modificadoPor: '',
//           fastRegister: false,
//         );

//         loteReporte.add(reporte);

//         if (loteReporte.length == loteSize) {
//           await serviceD.crearDetalleReporteEnLote(context, loteReporte);
//           loteReporte.clear();
//         }
//       }

//       if (loteReporte.isNotEmpty) {
//         await serviceD.crearDetalleReporteEnLote(context, loteReporte);
//       }

//       print('✅ Procesamiento completado');
//       return 1;
//     } catch (e) {
//       print('❌ Error al procesar archivo: $e');
//       return 0;
//     }
//   }

// // 🔧 Funciones auxiliares
//   int _parseInt(dynamic value) {
//     if (value is int) return value;
//     if (value is double) return value.toInt();
//     value = int.tryParse(value.toString());
//     return value;
//   }

//   double _parseDouble(dynamic value) {
//     if (value == null) return 0.0;
//     if (value is double) return value;
//     if (value is int) return value.toDouble();
//     value = double.tryParse(value.toString()) ?? 0;
//     return value;
//   }

//   String extractValue(String? input) {
//     if (input == null || !input.contains(':')) return input ?? '';
//     return input.split(':').skip(1).join(':').trim();
//   }

//   Future<int> processExcelPallet(
//       BuildContext context, String filePath, List<int> ReportesInfo) async {
//     try {
//       final file = await _validateFile(filePath);
//       if (file == null) return 0;

//       final bytes = file.readAsBytesSync();
//       final excel = Excel.decodeBytes(bytes);
//       final dbHelper = DatabaseHelper.instance;

//       if (!excel.tables.containsKey('Sheet1')) {
//         print('❌ Error: No se encontró la hoja "Sheet1" en el archivo Excel');
//         return 0;
//       }

//       final sheet = excel.tables['Sheet1']!;
//       if (sheet.rows.length < 5) {
//         print(
//             '⚠️ Advertencia: La hoja no tiene suficientes filas para procesar');
//         return 0;
//       }

//       final tim =
//           int.tryParse(extractValue(sheet.rows[1][1]?.value?.toString())) ?? 0;

//       if (ReportesInfo.contains(tim)) {
//         print('❌ Error: El TIM ya existe en la base de datos.');
//         return 0;
//       }
//       final nombre = await _userRepo.getNombreUsuario();
//       final reporteTim = ReporteTim(
//         tim: int.tryParse(extractValue(sheet.rows[1][1]?.value?.toString())) ??
//             0,
//         placa: 'Inventario',
//         localOrigen: extractValue(sheet.rows[2][1]?.value?.toString()),
//         localDestino: 'Inventario',
//         fechaEnvio: extractValue(sheet.rows[3][1]?.value?.toString()),
//         creadoPor: nombre,
//         motivo: 'I',
//       );

//       for (var i = 6; i < sheet.rows.length; i++) {
//         final row = sheet.rows[i];

//         final ean = row[2]?.value?.toString() ?? '';
//         if (ean.isEmpty) continue;

//         final reporte = Reporte(
//           id: '',
//           tim: reporteTim.tim,
//           olpn: row[1]?.value?.toString() ?? '',
//           ean: ean,
//           subdpto: row[8]?.value?.toString() ?? '',
//           sku: row[3]?.value?.toString() ?? '',
//           descripcion: row[4]?.value?.toString() ?? '',
//           casePack: _parseInt(row[9]?.value),
//           uMedida: '',
//           costoPromedio: _parseDouble(row[6]?.value),
//           precioVigente: 0,
//           uEnviadas: 0,
//           uRecibidas: _parseDouble(row[5]?.value),
//           fechavencimiento: row[10]?.value?.toString() ?? '',
//           observacion: '',
//           modificadoPor: nombre,
//           fastRegister: false,
//         );
//         await dbHelper.insertReport(reporte);
//       }
//       await dbHelper.insertReporteTim(reporteTim);
//       return 1;
//     } catch (e, stackTrace) {
//       print('❌ Error al procesar el archivo: $stackTrace');
//       return 0;
//     }
//   }
// }
