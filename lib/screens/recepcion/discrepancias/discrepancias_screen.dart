import 'dart:io';

import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:control_verde/utils/loading.dart';
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
  // bool _filtrosVisbles = true;
  bool _isFaltantesSelected =
      true; // Para saber si 'Faltantes' está seleccionado
  bool _isSobrantesSelected = false;

  ReporteTim? reportesInfo;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _textControllerConductor =
      TextEditingController();
  final TextEditingController _textControllerContador = TextEditingController();

  bool _filtrosVisbles = true;
  // TextEditingController _dateDesdeController = TextEditingController();
  // TextEditingController _dateHastaController = TextEditingController();
  // TextEditingController _codigoController = TextEditingController();
  // TextEditingController _descController = TextEditingController();
  // DateTime? _selectedDesdeDate;
  // DateTime? _selectedHastaDate;

  List<String> _subDeptOptions = [];

  ///
  Map<String, String> subDeptMap = {
    'Carnes': 'J03',
    'Frutas': 'J040101',
    'Verduras': 'J040102',
    'Fiambres y Huevos': 'J0501',
    'Leches': 'J050201',
    'Mantequillas': 'J050202',
    'Quesos': 'J050204',
    'Yogurts': 'J050205',
    'Helados': 'J050306',
    'Embutidos Congelados': 'J050301',
    'Panadería': 'J06',
    'Platos Preparados': 'J07',
    'Pizzas': 'J070109',
    'Lavado y Cuidado': 'J0201',
    'Cuidado e Higiene': 'J0202',
    'Mascotas': 'J0203',
    'Alimentos Bebés': 'J0204',
    'Vestuario': 'J08',
    'Hogar': 'J09',
    'Bazar': 'J10',
    'Muebles': 'J090204',
    'Electro': 'J11'
  };

  @override
  void initState() {
    super.initState();
    SocketService()
        .joinSala(widget.selectedTim.toString()); // Unir a la sala de recepción

    final socket = SocketService().socket;

    socket.on('producto-actualizado', (data) async {
      print('🟡 Producto actualizado desde otro dispositivo: $data');
      _recargarProductos();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarProductos(); // ya se puede usar context
    });
  }

  @override
  void dispose() {
    SocketService().leaveSala();
    super.dispose();
  }

  Future<void> _cargarProductos({int? tipoFiltro}) async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Cargando Productos');

    try {
      final serviceDR = DetalleReporteService();
      final serviceR = ReporteService();
      final productos =
          await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);
      final reporteInfo = await serviceR.obtenerReporte(widget.selectedTim);

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
        _subDeptOptions = _productosFiltrados
            .map((item) => item.subdpto) // Extraer los subdepartamentos
            .toSet() // Eliminar duplicados
            .toList(); // Conviertir de nuevo a lista
        reportesInfo = reporteInfo;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    } finally {
      Navigator.pop(dialogContext);
    }
  }

  Future<void> _recargarProductos({int? tipoFiltro}) async {
    try {
      final serviceDR = DetalleReporteService();
      final productos =
          await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);
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
        _subDeptOptions = _productosFiltrados
            .map((item) => item.subdpto) // Extraer los subdepartamentos
            .toSet() // Eliminar duplicados
            .toList(); // Conviertir de nuevo a lista
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  void _showReportDetails(BuildContext context, Reporte report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () async {
            _recargarProductos();
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
                  final String fechaEnvio = reportesInfo?.fechaEnvio ?? '';
                  final String origen = reportesInfo?.localOrigen ?? '';
                  final String destino = reportesInfo?.localDestino ?? '';
                  final String placa = reportesInfo?.placa ?? '';
                  final String tim = reportesInfo?.tim.toString() ?? '';
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
                      btnOkOnPress: () {},
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
    excel.sheets.remove('Sheet1');
    var sheet = excel['RMF'];
    var sheet1 = excel['SOBRANTES'];
    CellStyle styleCabecera = CellStyle(
      fontFamily: 'Calibri',
      fontSize: 8,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString("#3352FF"),
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
    String local_origen = reportesInfo?.localOrigen ?? '';
    String local_destino = reportesInfo?.localDestino ?? '';
    String tim = reportesInfo?.tim.toString() ?? '';

    List<String> destino = await local_destino.split(RegExp(r'\s*-\s*'));
    String codigoDestino = destino.first;
    String tiendaDestino = destino.length > 1 ? destino[1] : '';

    List<String> origen = await local_origen.split(RegExp(r'\s+'));
    String codigoOrigen = origen.first;
    String movilOrigen = origen.length > 1 ? origen.sublist(1).join(' ') : '';

    DateTime fecha = DateFormat("MMM d, yyyy hh:mm:ss a", "en_US")
        .parse(reportesInfo!.fechaEnvio!);

    String fechaEnvio = DateFormat("dd/MM/yy").format(fecha);
    String asunto = '';

    if (movilOrigen == "CD Secos") {
      asunto = "RMF_" +
          dateBitacora +
          "_" +
          codigoOrigen +
          "_TIM_" +
          tim +
          " " +
          codigoDestino +
          "_" +
          tiendaDestino; 
    } else {
      asunto = "DISCREPANCIA_" +
          dateBitacora +
          "_" +
          codigoOrigen +
          "_TIM_" +
          tim +
          " " +
          codigoDestino +
          "_" +
          tiendaDestino;
    }

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
      'ASUNTO',
      'TIM',
      'OLPN',
      'DEPARTAMENTO',
      'SKU',
      'EAN',
      'DESCRIPCIÓN DE SKU',
      'UNIDAD DE MEDIDA',
      'CANTIDAD EN GUIA REMISION',
      'CANTIDAD RECIBIDA',
      'DIFERENCIA',
      'COSTO PROMEDIO',
      'MONTO FALTANTE (S/)',
      'RESPONSABLE DE GENERAR EL REQUERIMIENTO',
    ];
    headers.asMap().forEach((colIndex, headerText) {
      var cell = sheet.cell(xcl.CellIndex.indexByColumnRow(
          columnIndex: colIndex, rowIndex: rowIndex));
      cell.value = xcl.TextCellValue(headerText);
      cell.cellStyle = styleCabecera;
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
        TextCellValue(asunto),
        TextCellValue(tim),
        TextCellValue(report.olpn),
        TextCellValue(report.subdpto),
        TextCellValue(report.sku),
        TextCellValue(report.ean),
        TextCellValue(report.descripcion),
        TextCellValue(report.uMedida),
        DoubleCellValue(report.uEnviadas),
        DoubleCellValue(report.uRecibidas),
        DoubleCellValue(report.uRecibidas - report.uEnviadas),
        DoubleCellValue(report.costoPromedio),
        await DoubleCellValue(
            report.costoPromedio * (report.uRecibidas - report.uEnviadas)),
        TextCellValue(contador),
      ]);
    }

    sheet1.appendRow([
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('Sub Departamento'),
      TextCellValue('Cajas Enviadas'),
      TextCellValue('Uni Enviadas'),
      TextCellValue('Cajas Recibidas'),
      TextCellValue('Uni Recibidas'),
      TextCellValue('Uni Sobrantes'),
      TextCellValue('Costo Promedio'),
      TextCellValue('Costo Total'),
    ]);

    for (var report in _productosSobrantes) {
      var cantidadSobrante = report.uRecibidas - report.uEnviadas;
      sheet1.appendRow([
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        TextCellValue(report.subdpto),
        DoubleCellValue(report.uEnviadas / report.casePack),
        DoubleCellValue(report.uEnviadas),
        DoubleCellValue(report.uRecibidas / report.casePack),
        DoubleCellValue(report.uRecibidas),
        DoubleCellValue(cantidadSobrante),
        DoubleCellValue(report.costoPromedio),
        DoubleCellValue(report.costoPromedio * cantidadSobrante)
      ]);
    }

    String fileName = 'BITACORA_${reportesInfo!.tim}_$formattedDate.xlsx';

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
          icon: Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: _filtrosVisbles
                ? Icon(Icons.filter_list_off)
                : Icon(Icons.filter_list),
            onPressed: () => {
              setState(() {
                _filtrosVisbles = !_filtrosVisbles;
              })
            },
          ),
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
                        _recargarProductos();
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
                        _recargarProductos(tipoFiltro: 1);
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
                // Visibility(
                //   visible: _filtrosVisbles,
                //   child: Column(
                //     children: [
                //       Row(
                //         children: [
                //           Expanded(
                //             child: DropdownButtonFormField<String>(
                //               value: _subDeptFiltro,
                //               decoration: InputDecoration(
                //                 labelText: 'SubDept',
                //                 border: OutlineInputBorder(),
                //                 contentPadding: EdgeInsets.symmetric(
                //                     vertical: 8.0, horizontal: 8.0),
                //                 suffixIcon: _subDeptFiltro != null
                //                     ? IconButton(
                //                         icon: Icon(Icons.close,
                //                             color: Colors.red),
                //                         onPressed: () {
                //                           setState(() {
                //                             _subDeptFiltro = null;
                //                           });
                //                           _actualizarFiltro();
                //                         },
                //                       )
                //                     : Icon(Icons.arrow_drop_down,
                //                         color: Colors.amber),
                //               ),
                //               items: _subDeptOptions.map((String option) {
                //                 return DropdownMenuItem<String>(
                //                   value: option,
                //                   child: Text(option),
                //                 );
                //               }).toList(),
                //               onChanged: (String? newValue) {
                //                 setState(() {
                //                   _subDeptFiltro = newValue;
                //                 });
                //                 _actualizarFiltro();
                //               },
                //             ),
                //           ),
                //         ],
                //       ),
                //       SizedBox(height: 12),
                //     ],
                //   ),
                // ),

                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  child: IconButton(
                    onPressed: () {
                      _showExportDialog(context);
                    },
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Reportar',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white),
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
                                                text: 'Sku: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '${producto.sku}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: Colors.black,
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
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '${producto.subdpto}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: Colors.black,
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
                                                text: 'Cajas: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${producto.uEnviadas / producto.casePack}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: Colors.black,
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
                                                text: 'Unidades: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '${producto.uEnviadas}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.normal,
                                                  color: Colors.black,
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
                                                      text: 'Registrados: ',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight
                                                            .bold, // Negrita
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          '${producto.uRecibidas.toString()}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                producto.uRecibidas ==
                                                        producto.uEnviadas
                                                    ? Icons.check
                                                    : Icons.warning,
                                                color: producto.uRecibidas ==
                                                        producto.uEnviadas
                                                    ? Colors.green
                                                    : producto.uRecibidas > 0 &&
                                                            producto.uRecibidas <
                                                                producto
                                                                    .uEnviadas
                                                        ? Colors.amber
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
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      margin: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                              fontWeight: FontWeight.bold,
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
