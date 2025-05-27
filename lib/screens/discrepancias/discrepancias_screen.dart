import 'dart:io';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:excel/excel.dart' as xcl;
import 'package:excel/excel.dart'
    show 
        CellStyle,
        DoubleCellValue,
        ExcelColor,
        HorizontalAlign,
        TextCellValue,
        VerticalAlign;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DiscrepanciasScreen extends StatefulWidget {
  final int selectedTim;
  const DiscrepanciasScreen({required this.selectedTim});

  @override
  _DiscrepanciasScreen createState() => _DiscrepanciasScreen();
}

class _DiscrepanciasScreen extends State<DiscrepanciasScreen> {
  List<Producto> data_maestro = [];
  List<Reporte> _productosFiltrados = [];
  List<Reporte> _productosFaltantes = [];
  List<Reporte> _productosSobrantes = [];
  // String? _descripcionFiltro;
  // String? _eanFiltro;
  // String? _subDeptFiltro;
  // bool _filtrosVisbles = true;
  bool _isFaltantesSelected =
      true; // Para saber si 'Faltantes' está seleccionado
  bool _isSobrantesSelected = false;

  List<ReporteTim> reportesInfo = [];

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _textControllerConductor =
      TextEditingController();
  final TextEditingController _textControllerContador = TextEditingController();

  // TextEditingController _dateDesdeController = TextEditingController();
  // TextEditingController _dateHastaController = TextEditingController();
  // TextEditingController _codigoController = TextEditingController();
  // TextEditingController _descController = TextEditingController();
  // DateTime? _selectedDesdeDate;
  // DateTime? _selectedHastaDate;

  ///List<String> _subDeptOptions = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos({int? tipoFiltro}) async {
    try {
      final productos =
          await DatabaseHelper.instance.getReportesByTim(widget.selectedTim);
      final reporteInfo = await DatabaseHelper.instance.getReporteTimByTim(widget.selectedTim);

      setState(() {
        _productosFaltantes = productos.where((item) {
          return item.uEnviadas > item.uRecibidas;
        }).toList();

        _productosSobrantes = productos.where((item) {
          return item.uEnviadas < item.uRecibidas;
        }).toList();

        _productosFiltrados = (tipoFiltro == null || tipoFiltro == 0)
            ? _productosFaltantes
            : _productosSobrantes;
        reportesInfo = reporteInfo;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  // Future<void> _cargarProductos() async {
  //   try {
  //     final productos =
  //         await DatabaseHelper.instance.getReportesByTim(widget.selectedTim);
  //     final reporteInfo = await DatabaseHelper.instance.fetchReporteTim();

  //     setState(() {
  //       _productosFaltantes = productos.where((item) {
  //         return item.uEnviadas > item.uRecibidas;
  //       }).toList();
  //       _productosSobrantes = productos.where((item) {
  //         return item.uEnviadas < item.uRecibidas;
  //       }).toList();

  //       _productosFiltrados = _productosFaltantes;
  //       reportesInfo = reporteInfo;
  //     });
  //   } catch (error) {
  //     print('Error al cargar productos: $error');
  //   }
  // }

  // void _actualizarFiltro() {
  //   setState(() {
  //     _productosFiltrados = _productos.where((item) {
  //       bool descripcionMatch = _descripcionFiltro == null ||
  //           item.descripcion
  //               .toLowerCase()
  //               .contains(_descripcionFiltro!.toLowerCase());

  //       // Filtro de EAN
  //       bool eanMatch = _eanFiltro == null || item.ean.contains(_eanFiltro!);

  //       // Filtro de SubDepartamento
  //       bool subDeptMatch = _subDeptFiltro == null ||
  //           item.subdpto.toLowerCase().contains(_subDeptFiltro!.toLowerCase());

  //       // Filtro de fecha desde
  //       bool desdeMatch = true;
  //       if (_selectedDesdeDate != null) {
  //         if (item.fechavencimiento != "dd/mm/yy" &&
  //             item.fechavencimiento != null &&
  //             item.fechavencimiento.isNotEmpty) {
  //           DateTime fechaVencimiento = _convertirFecha(item.fechavencimiento);
  //           desdeMatch = fechaVencimiento.isAfter(_selectedDesdeDate!);
  //         } else {
  //           desdeMatch == false;
  //         }
  //       }

  //       // Filtro de fecha hasta
  //       bool hastaMatch = true;
  //       if (_selectedHastaDate != null) {
  //         if (item.fechavencimiento != "dd/mm/yy" &&
  //             item.fechavencimiento != null &&
  //             item.fechavencimiento.isNotEmpty) {
  //           DateTime fechaVencimiento = _convertirFecha(item.fechavencimiento);
  //           hastaMatch = fechaVencimiento.isBefore(_selectedHastaDate!);
  //         } else {
  //           hastaMatch = false;
  //         }
  //       }

  //       // Combinamos todos los filtros
  //       return descripcionMatch &&
  //           eanMatch &&
  //           subDeptMatch &&
  //           desdeMatch &&
  //           hastaMatch;
  //     }).toList();
  //   });
  // }

  // Future<void> _selectDesdeDate(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );
  //   if (picked != null && picked != _selectedDesdeDate) {
  //     setState(() {
  //       _selectedDesdeDate = picked;
  //       _dateDesdeController.text =
  //           DateFormat('yyyy-MM-dd').format(picked); // Formato de fecha
  //     });
  //     _actualizarFiltro();
  //   }
  // }

  // Future<void> _selectHastaDate(BuildContext context) async {
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: DateTime.now(),
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //   );
  //   if (picked != null && picked != _selectedHastaDate) {
  //     setState(() {
  //       _selectedHastaDate = picked;
  //       _dateHastaController.text =
  //           DateFormat('yyyy-MM-dd').format(picked); // Formato de fecha
  //     });

  //     _actualizarFiltro();
  //   }
  // }

  // DateTime _convertirFecha(String fecha) {
  //   // Suponemos que el formato es "dd/MM/yyyy"
  //   List<String> partesFecha = fecha.split('/');
  //   return DateTime(
  //     int.parse(partesFecha[2]), // Año
  //     int.parse(partesFecha[1]), // Mes
  //     int.parse(partesFecha[0]), // Día
  //   );
  // }

  void _showReportDetails(BuildContext context, Reporte report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () async {
            _cargarProductos();
            // reportes = await _loadReports();
            // _filterReports("");
          },
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Completar Datos'),
          content: SizedBox(
            height: 200,
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Empresa Transporte',
                    hintText: '',
                  ),
                ),
                TextField(
                  controller: _textControllerConductor,
                  decoration: const InputDecoration(
                    labelText: 'Conductor',
                  ),
                ),
                TextField(
                  controller: _textControllerContador,
                  decoration: const InputDecoration(
                    labelText: 'Contador',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                )),
            ElevatedButton(
                onPressed: () async {
                  final String nombreUsuario = _textController.text;
                  final String conductor = _textControllerConductor.text;
                  final String contador = _textControllerContador.text;
                  final String fechaEnvio = reportesInfo.first.fechaEnvio!;
                  final String origen = reportesInfo.first.localOrigen!;
                  final String destino = reportesInfo.first.localDestino!;
                  final String placa = reportesInfo.first.placa!;
                  final String tim = reportesInfo.first.tim.toString();
                  final String discrepancia =
                      (_productosFaltantes.length).toString();
                  final String sobrante =
                      (_productosSobrantes.length).toString();
                  if (nombreUsuario.isNotEmpty &&
                      conductor.isNotEmpty &&
                      contador.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Confirmar'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Empresa Transporte: $nombreUsuario'),
                              Text('Conductor: $conductor'),
                              Text('Contador: $contador'),
                              Text('Fecha Envío: $fechaEnvio'),
                              Text('Origen: $origen'),
                              Text('Destino: $destino'),
                              Text('Placa: $placa'),
                              Text('TIM: $tim'),
                              Text('Productos Faltantes: $discrepancia'),
                              Text('Productos Sobrantes: $sobrante'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                String filePath = await exportToExcel();
                                AwesomeDialog(
                                  context: context,
                                  dialogType: DialogType.success,
                                  animType: AnimType.scale,
                                  title: 'Archivo exportado',
                                  desc:
                                      'El archivo ha sido guardado en: $filePath',
                                  btnOkOnPress: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                  },
                                ).show();
                              },
                              child: Text(
                                'Todo Ok ',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ],
                        );
                      },
                    );

                  } else {
                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.warning,
                      animType: AnimType.scale,
                      title: 'Ingrese su Nombre ',
                      desc: 'Es necesario Nombre',
                      btnOkOnPress: () {
                      },
                    ).show();
                  }
                },
                child: const Text(
                  'Continuar',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green,
                )),
          ],
        );
      },
    );
  }

  Future<String> exportToExcel() async {
    var excel = xcl.Excel.createExcel();
    excel.delete('Sheet1');
    var sheet = excel['RMF'];
    var sheet1 = excel['SOBRANTES'];
    CellStyle style = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString("3352FF"),
      bottomBorder: xcl.Border(borderStyle: xcl.BorderStyle.Thin),
      topBorder: xcl.Border(borderStyle: xcl.BorderStyle.Thin),
      leftBorder: xcl.Border(borderStyle: xcl.BorderStyle.Thin),
      rightBorder: xcl.Border(borderStyle: xcl.BorderStyle.Thin),
    );


    String empresaTransporte = _textController.text;
    String conductor = _textControllerConductor.text;
    String contador = _textControllerContador.text;

    String formattedDate = DateFormat('dd-MM-yy').format(DateTime.now());
    String dateBitacora = DateFormat('dd/MM/yy').format(DateTime.now());
    String local_origen = reportesInfo.first.localOrigen!;
    String local_destino = reportesInfo.first.localDestino!;
    String tim = reportesInfo.first.tim.toString();

    List<String> destino = local_destino.split(RegExp(r'\s*-\s*'));
    String codigoDestino = destino.first;
    String tiendaDestino = destino.length > 1 ? destino[1] : '';

    List<String> origen = local_origen.split(RegExp(r'\s+'));
    String codigoOrigen = origen.first;
    String movilOrigen = origen.length > 1 ? origen.sublist(1).join(' ') : '';

    DateTime fecha =
        DateFormat("MMM d, yyyy hh:mm:ss a", "en_US").parse(reportesInfo.first.fechaEnvio!);

    String fechaEnvio = DateFormat("dd/MM/yy").format(fecha);

    String asunto = "RMF_" +
        dateBitacora +
        "_" +
        codigoOrigen +
        "_TIM_" +
        tim +
        " " +
        codigoDestino +
        "_" +
        tiendaDestino; //ASUNTO
    var rowIndex = sheet.maxRows;
    List<String> headers = [
      'FECHA ENVÍO',
      'FECHA RECEPCIÓN',
      'CÓDIGO DE TIENDA',
      'TIENDA',
      'ORIGEN',
      'MÓVIL',
      'EMPRESA DE TRANSPORTE',
      'CONDUCTOR',
      'MONTO FALTANTE (S/)',
      'ASUNTO',
      'DEPARTAMENTO',
      'TIM',
      'OLPN',
      'SKU',
      'DESCRIPCIÓN DE SKU',
      'UNIDAD DE MEDIDA',
      'CANTIDAD EN GUIA REMISION',
      'CANTIDAD RECIBIDA',
      'DIFERENCIA',
      'COSTO PROMEDIO',
      'RESPONSABLE DE GENERAR EL REQUERIMIENTO',
    ];
    headers.asMap().forEach((colIndex, headerText) {
      var cell = sheet.cell(xcl.CellIndex.indexByColumnRow(
          columnIndex: colIndex, rowIndex: rowIndex));
      cell.value = xcl.TextCellValue(headerText);
      cell.cellStyle = style;
    });

    for (var report in _productosFiltrados) {
      sheet.appendRow([
        TextCellValue(fechaEnvio),
        TextCellValue(dateBitacora),
        TextCellValue(codigoDestino),
        TextCellValue(tiendaDestino),
        TextCellValue(codigoOrigen),
        TextCellValue(movilOrigen),
        TextCellValue(empresaTransporte),
        TextCellValue(conductor),
        await DoubleCellValue(
            report.costoPromedio * (report.uRecibidas - report.uEnviadas)),
        TextCellValue(asunto),
        TextCellValue(report.subdpto),
        TextCellValue(tim),
        TextCellValue(report.olpn),
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        TextCellValue(report.uMedida ),
        DoubleCellValue(report.uEnviadas),
        DoubleCellValue(report.uRecibidas),
        DoubleCellValue(report.uRecibidas - report.uEnviadas),
        DoubleCellValue(report.costoPromedio),
        TextCellValue(contador),
      ]);
    }

    sheet1.appendRow([
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('Sub Departamento'),
      TextCellValue('Cajas Recibidas'),
      TextCellValue('Uni Recibidas'),
      TextCellValue('Fecha Vencimiento'),
    ]);

    for (var report in _productosSobrantes) {
      sheet1.appendRow([
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        TextCellValue(report.subdpto),
        DoubleCellValue(report.uRecibidas/report.casePack),
        DoubleCellValue(report.uRecibidas),
        TextCellValue(report.fechavencimiento),
      ]);
    }

    String fileName =
        'BITACORA_${reportesInfo.first.tim}_$formattedDate.xlsx';

    try {
      final downloadDirectory = Directory('/storage/emulated/0/Download');
      final filePath = '${downloadDirectory.path}/$fileName';

      if (!await downloadDirectory.exists()) {
        await downloadDirectory.create(recursive: true);
      }
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);
      return filePath;
    } catch (e) {
      return "Error $e";
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Discrepancias', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // IconButton(
          //   icon: _filtrosVisbles
          //       ? Icon(Icons.filter_list_off)
          //       : Icon(Icons.filter_list),
          //   onPressed: () => {
          //     setState(() {
          //       _filtrosVisbles = !_filtrosVisbles;
          //     })
          //   },
          //   //tooltip: '',
          // ),
          // IconButton(
          //   icon: const Icon(Icons.more_vert),
          //   onPressed: () => _showOptionsMenu(context),
          //   // tooltip: 'Exportar',
          // ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        _cargarProductos();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: _isFaltantesSelected
                            ? Colors.grey
                            : Colors.transparent,
                        // primary: _isFaltantesSelected
                        //     ? Colors.white
                        //     : Colors.blue,
                      ),
                      child: Text('Faltantes'),
                    ),
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _cargarProductos(tipoFiltro: 1);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: _isSobrantesSelected
                            ? Colors.grey
                            : Colors.transparent, 
                        // : _isSobrantesSelected
                        //     ? Colors.white
                        //     : Colors.green,
                      ),
                      child: Text('Sobrantes'),
                    ),
                  ],
                ),

                Material(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.circular(8), 
                  child: IconButton(
                    onPressed: () {
                      _showExportDialog(context);
                    },
                    icon: Row(
                      mainAxisSize: MainAxisSize
                          .min,
                      children: [
                        Text(
                          'Reportar',
                          style:
                              TextStyle(color: Colors.white),
                        ),
                        Icon(Icons.chevron_right,
                            color: Colors
                                .white),
                      ],
                    ),
                  ),
                )

                // TextButton(
                //     onPressed: () {}, child: Text('Fecha de Fencimientos')),
              ],
            ),

            // ? const Center(child: CircularProgressIndicator())
            Column(
              children: [
                Container(
                  height: 600,
                  // constraints: const BoxConstraints(
                  //   maxHeight: 100,
                  // ),
                  child: ListView.builder(
                    itemCount: _productosFiltrados.length,
                    itemBuilder: (context, index) {
                      var producto = _productosFiltrados[index];
                      return Card(
                        elevation: 4,
                        // margin: const EdgeInsets.symmetric(
                        //     vertical: 8.0,
                        //     horizontal: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  producto.descripcion.trim(),
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),

                              // Container(
                              //   padding: const EdgeInsets.symmetric(
                              //       horizontal: 8, vertical: 1),
                              //   decoration: BoxDecoration(
                              //     color: Colors.green,
                              //     borderRadius: BorderRadius.circular(8),
                              //   ),
                              //   child: const Text(
                              //     'Registrado',
                              //     style: TextStyle(
                              //       color: Colors.white,
                              //     ),
                              //   ),
                              // )
                            ],
                          ),
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'Sku: ', 
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold, 
                                                  color: Colors
                                                      .black, 
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${producto.sku}', 
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .normal, 
                                                  color: Colors
                                                      .black, 
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Sub Dpto: ', 
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold, 
                                                  color: Colors
                                                      .black, 
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${producto.subdpto}', 
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .normal, 
                                                  color: Colors
                                                      .black, 
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'Cajas: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold,
                                                  color: Colors
                                                      .black,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${producto.cEnviadas}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .normal, 
                                                  color: Colors
                                                      .black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'Unidades: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold,
                                                  color: Colors
                                                      .black,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${producto.uEnviadas}', 
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .normal, 
                                                  color: Colors
                                                      .black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (producto.uRecibidas != 0)
                                          Row(
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    const TextSpan(
                                                      text:
                                                          'Registrados: ',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight
                                                            .bold, // Negrita
                                                        color: Colors
                                                            .black, 
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          '${producto.uRecibidas.toString()}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight
                                                            .normal,
                                                        color: Colors
                                                            .black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                producto.uRecibidas ==
                                                        producto.uEnviadas
                                                    ? Icons.check
                                                    : Icons
                                                        .warning,
                                                color: producto.uRecibidas ==
                                                        producto.uEnviadas
                                                    ? Colors
                                                        .green
                                                    : producto.uRecibidas > 0 &&
                                                            producto.uRecibidas <
                                                                producto
                                                                    .uEnviadas
                                                        ? Colors
                                                            .amber 
                                                        : Colors.red,
                                              ),
                                            ],
                                          ),

                                        // Container(
                                        //   padding:
                                        //       const EdgeInsets.symmetric(
                                        //           horizontal: 8,
                                        //           vertical: 1),
                                        //   decoration: BoxDecoration(
                                        //     color: producto.recibidos ==
                                        //             producto.unidades
                                        //         ? Colors
                                        //             .green
                                        //         : producto.recibidos > 0 &&
                                        //                 producto.recibidos <
                                        //                     producto
                                        //                         .unidades
                                        //             ? Colors
                                        //                 .amber
                                        //             : Colors
                                        //                 .red,
                                        //     borderRadius:
                                        //         BorderRadius.circular(8),
                                        //   ),
                                        //   child: Row(
                                        //     children: [
                                        //       Icon(
                                        //         producto.recibidos ==
                                        //                 producto.unidades
                                        //             ? Icons.check
                                        //             : Icons
                                        //                 .warning,
                                        //         color: Colors.white,
                                        //       ),
                                        //       Text(
                                        //         producto.recibidos
                                        //             .toString(),
                                        //         style: TextStyle(
                                        //             color: Colors.white),
                                        //       ),
                                        //     ],
                                        //   ),
                                        // )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Text(
                              //   'Registrado ',
                              //   style: const TextStyle(
                              //       color: Colors.white,
                              //       backgroundColor: Colors.green),
                              // ),
                            ],
                          ),

                          onTap: () {
                            _showReportDetails(context, producto);
                          },
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 50,
                      padding: EdgeInsets.symmetric(
                          horizontal: 20),
                      margin:
                          EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius:
                            BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        children: [
                          // Icon(Icons.info_outline,
                          //     color: Colors.white),
                          // SizedBox(
                          //     width: 8),
                          Text(
                            'Total: ${_productosFiltrados.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
