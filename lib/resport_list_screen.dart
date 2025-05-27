import 'dart:io';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:flutter/material.dart';
import './screens/qr/mobile_scanner.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:excel/excel.dart' show Sheet, Excel, TextCellValue, IntCellValue, DoubleCellValue;

import 'package:intl/intl.dart';

class ReportListScreen extends StatefulWidget {
  @override
  _ReportListScreenState createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  // Lista para almacenar los reportes
  List<Reporte> reportes = [];
  List<ReporteTim> reportesInfo = [];
  List<Reporte> _filteredReports = [];

  List<String> subDepartments = [];
  List<String> _filtersubDepartments = [];

  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _codigoController = TextEditingController();

  bool _isSearchVisible = false;
  bool _isCodigoVisible = false;
  bool _isInfoVisible = true;
  bool _isListUbiVisible = true;
  final FocusNode _focusNode = FocusNode(); // Hacemos que sea final

  Future<List<ReporteTim>> repotetim = Future.value([]);

  @override
  void initState() {
    super.initState();
    //_loadReports();

    _codigoController.addListener(() {
      _filterReports(_codigoController.text);
    });
    fetchSubDepartments();
    repotetim = DatabaseHelper.instance.fetchReporteTim();
    _loadReports();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();

    _codigoController.dispose();

    super.dispose();
  }

  Future<List<Reporte>> _loadReports() async {
    try {
      // Obtener los datos de la base de datos
      reportes = await DatabaseHelper.instance.getReportes();

      // Devolver la lista de reportes
      return reportes;
    } catch (e) {
      print('Error al cargar los reportes: $e');
      return []; // Devolver una lista vacía en caso de error
    }
  }

  void fetchSubDepartments() async {
    subDepartments = await DatabaseHelper.instance.getSubDepartments();
    print(subDepartments);
  }

  void _filterReportsBySupDept(String subDept) async {
    if (reportes.isEmpty) {
      setState(() {
        _filteredReports =
            reportes.where((report) => report.subdpto == subDept).toList();
      });
    }
  }

  void _filterSubDepts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filtersubDepartments =
            List.from(subDepartments); // Mostrar todo si está vacío
        _filtersubDepartments = subDepartments;
      });
      //  setState(() {

      //});
    } else {
      setState(() {
        _filtersubDepartments = subDepartments
            .where((subdpto) =>
                subdpto.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });

      final reports = await reportes;
      if (reportes.isNotEmpty) {
        setState(() {
          _filteredReports = reports
              .where((report) =>
                  report.subdpto.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
      }
    }
  }

  void _filterReports(String query) {
    final filteredReports = reportes.where((report) {
      final sku = report.sku.toLowerCase();
      // final ean = report.ean?.toLowerCase() ?? '';
      return sku.contains(query.trim().toLowerCase());
      // if (query.trim().length > 9) {
      //   return ean.contains(query.trim().toLowerCase());
      // } else {
      //   return sku.contains(query.trim().toLowerCase());
      // }
    }).toList();

    setState(() {
      _filteredReports = filteredReports;
    });
  }

  void _showReportDetails(BuildContext context, Reporte report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () async {
            reportes = await _loadReports();
            _filterReports("");
          },
        );
      },
    );
  }

  Future<String> exportToExcel(List<Reporte> reports, String nombre) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    ///Sheet sheet = excel['Reportes'];
    sheet.appendRow([TextCellValue('Preventores: '), TextCellValue(nombre)]);
    sheet.appendRow([TextCellValue('Tim: '), IntCellValue(reportesInfo.first.tim)]);
    sheet.appendRow([TextCellValue('Placa: '), TextCellValue(reportesInfo.first.placa!)]);
    sheet.appendRow([TextCellValue('Origen: '), TextCellValue(reportesInfo.first.localOrigen!)]);
    sheet.appendRow([TextCellValue('Destino: '), TextCellValue(reportesInfo.first.localDestino!)]);
    sheet.appendRow([TextCellValue('Fecha envío: '), TextCellValue(reportesInfo.first.fechaEnvio!)]);

    // Agregar un espacio antes de los encabezados
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      // 'EAN',
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('Sub Departamento'),
      TextCellValue('Uni Enviadas'),
      TextCellValue('Cajas Enviadas'),
      TextCellValue('Uni Recibidas'),
      TextCellValue('Fecha Vencimiento'),
    ]);

    for (var report in reports) {
      sheet.appendRow([
        // report.ean ?? 0,
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        TextCellValue(report.subdpto),
        DoubleCellValue(report.uEnviadas),
        DoubleCellValue(report.cEnviadas),
        DoubleCellValue(report.uRecibidas),
        TextCellValue(report.fechavencimiento),
      ]);
    }

    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    String fileName = 'reportes_$formattedDate.xlsx';

    try {
      final downloadDirectory = Directory('/storage/emulated/0/Download');
      final filePath = '${downloadDirectory.path}/$fileName';

      if (!await downloadDirectory.exists()) {
        await downloadDirectory.create(recursive: true);
      }
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);

      // Mostrar una notificación al usuario
      print('Archivo guardado en: $filePath');
      return filePath; // Retorna la ubicación del archivo
    } catch (e) {
      return "Error $e";
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lista de Reportes'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _showExportDialog(context),
            tooltip: 'Exportar',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Visibility(
                visible: _isInfoVisible,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FutureBuilder<List<ReporteTim>>(
                        future: repotetim,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text('No hay informacion del reporte'),
                            );
                          }

                          reportesInfo = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap:
                                true, // Asegúrate de usar shrinkWrap si está dentro de un widget que restringe el tamaño
                            physics:
                                const NeverScrollableScrollPhysics(), // Evita conflictos de scroll
                            itemCount: reportesInfo.length,
                            itemBuilder: (context, index) {
                              final reporte = reportesInfo[index];
                              return
                                  // Card(
                                  //   margin: const EdgeInsets.symmetric(
                                  //       horizontal: 16, vertical: 8),
                                  //   child:
                                  ListTile(
                                title: Text(
                                  'TIM: ${reporte.tim}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Text(
                                    //     'Fecha Generación: ${reporte.fechaGeneracion}'),
                                    // Text('Shipment: ${reporte.shipment}'),
                                    // Text('Placa: ${reporte.placa}'),
                                    Text('Origen: ${reporte.localOrigen}'),
                                    //Text('Destino: ${reporte.localDestino}'),
                                    Text('Fecha Envío: ${reporte.fechaEnvio}'),
                                  ],
                                ),

                                //isThreeLine: true,
                              );
                              // );
                            },
                          );
                        },
                      ),
                    )

                    // Column(
                    //   children: [
                    //     Text(
                    //       "120",
                    //       style: TextStyle(fontSize: 16),
                    //     ),
                    //     Container(
                    //       padding: EdgeInsets.symmetric(
                    //           horizontal: 2.0, vertical: 0.0),
                    //       decoration: BoxDecoration(
                    //         color: Colors.blue,
                    //         borderRadius: BorderRadius.circular(4.0),
                    //       ),
                    //       child: Text(
                    //         "Recibidos",
                    //         style: TextStyle(
                    //             color: Colors.white,
                    //             fontSize: 16 // Color del texto
                    //             ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    // Column(
                    //   children: [
                    //     Text(
                    //       "121",
                    //       //  producto.estado,
                    //       style: TextStyle(
                    //           //color: Colors.white,
                    //           fontSize: 16 // Color del texto
                    //           ),
                    //     ),
                    //     Container(
                    //       padding: EdgeInsets.symmetric(
                    //           horizontal: 2.0,
                    //           vertical: 0.0), // Espaciado interno
                    //       decoration: BoxDecoration(
                    //         color: Colors.blue, //_getEstadoColor(producto
                    //         //.estado), // Color de fondo según el estado
                    //         borderRadius: BorderRadius.circular(
                    //             4.0), // Bordes redondeados
                    //       ),
                    //       child: Text(
                    //         "Faltantes",
                    //         //  producto.estado,
                    //         style: TextStyle(
                    //             color: Colors.white,
                    //             fontSize: 16 // Color del texto
                    //             ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
              Visibility(
                visible: _isSearchVisible,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode:
                              _focusNode, // Abre el teclado automáticamente
                          controller: _searchController,
                          onChanged: (value) {
                            _filterSubDepts(
                                value); // Filtra ubicaciones mientras se escribe
                            _isListUbiVisible = true;
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar por dpto...',
                            // Borde redondeado
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.0),
                              borderSide: BorderSide.none, // Sin borde visible
                            ),
                            filled: true,
                            fillColor:
                                Colors.grey[200], // Fondo de la caja de texto
                            // prefixIcon: Icon(
                            //     Icons.search),
                            suffixIcon: IconButton(
                              icon: Icon(Icons
                                  .arrow_drop_down), // Ícono de "X" para borrar texto
                              onPressed: () {
                                setState(() {
                                  if (_searchController.text.isEmpty) {
                                    _isListUbiVisible = true;

                                    _searchController.text = 'Todosss';
                                  } else {
                                    _isListUbiVisible = false;

                                    _searchController.text = '';
                                  }
                                });

                                _searchController.clear();
                                _filterSubDepts(
                                    ''); // Refiltrar con texto vacío
                              },
                            ),
                            // Estilo cuando el TextField está enfocado
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.0),
                              borderSide: BorderSide(
                                  color: Colors.blueAccent, width: 2.0),
                            ),
                            // Estilo del borde cuando no está enfocado
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30.0),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                          ),
                        ),
                      ),

                      // Espacio entre la caja de texto y la X externa
                      SizedBox(width: 10),

                      // Botón "X" externo para cerrar el buscador completo
                      IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.red), // Ícono de "X" rojo
                        onPressed: () {
                          // Ocultar buscador y cerrar el teclado
                          _searchController
                              .clear(); // Limpia el contenido del campo de texto

                          FocusScope.of(context).unfocus(); // Cierra el teclado
                          _filterReports('');
                          setState(() {
                            _isSearchVisible = false; // Oculta el buscador
                            // filteredUbicaciones
                            //     .clear(); // Limpiar la lista de ubicaciones filtradas
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Visibility(
                visible: _isCodigoVisible,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  child: TextField(
                    controller: _codigoController, // Asocia el controlador
                    decoration: InputDecoration(
                      labelText: 'Código Escaneado',
                      labelStyle: TextStyle(
                          color: Colors.black54), // Color de la etiqueta
                      filled: true, // Habilita el fondo
                      fillColor: Colors.white, // Color de fondo
                      border: OutlineInputBorder(
                        // Borde
                        borderRadius:
                            BorderRadius.circular(20), // Bordes redondeados
                        borderSide: BorderSide(
                          color: Colors.orange,
                          width: 2, // Ancho del borde
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.blue, // Color del borde al enfocar
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        // Borde cuando está habilitado
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors
                              .orange, // Color del borde al estar habilitado
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Reporte>>(
                  // Asumimos que 'getReports()' es una función que devuelve un Future<List<Reporte>>
                  future: _loadReports(),
                  builder: (context, snapshot) {
                    // Estado mientras se cargan los datos
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Estado si ocurre un error en la carga
                    else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    // Estado si no hay datos o la lista está vacía
                    else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('No hay reportes disponibles'));
                    }
                    // Estado cuando se tienen los datos cargados correctamente
                    else {
                      final reports = _filteredReports.isEmpty
                          ? snapshot.data!
                          : _filteredReports;
                      //final reports = _filteredReports;
                      return ListView.builder(
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 15),
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(10),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}.SKU:  ${report.sku}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (report.uRecibidas != 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Registrado',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                ],
                              ),
                              subtitle: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 8),
                                        Text(
                                          report.descripcion.trim(),
                                          style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'Sub Depto: ', // Texto fijo
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .bold, // Negrita
                                                  color: Colors
                                                      .black, // Color del texto
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${report.subdpto}', // Texto variable
                                                style: TextStyle(
                                                  fontWeight: FontWeight
                                                      .normal, // Normal
                                                  color: Colors
                                                      .black, // Color del texto
                                                ),
                                              ),
                                            ],
                                          ),
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
                                                        'Cajas: ', // Texto fijo
                                                    style: TextStyle(
                                                      fontWeight: FontWeight
                                                          .bold, // Negrita
                                                      color: Colors
                                                          .black, // Color del texto
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        '${report.cEnviadas}', // Texto variable
                                                    style: TextStyle(
                                                      fontWeight: FontWeight
                                                          .normal, // Normal
                                                      color: Colors
                                                          .black, // Color del texto
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  const TextSpan(
                                                    text:
                                                        'Uidades: ', // Texto fijo
                                                    style: TextStyle(
                                                      fontWeight: FontWeight
                                                          .bold, // Negrita
                                                      color: Colors
                                                          .black, // Color del texto
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        '${report.uEnviadas}', // Texto variable
                                                    style: TextStyle(
                                                      fontWeight: FontWeight
                                                          .normal, // Normal
                                                      color: Colors
                                                          .black, // Color del texto
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
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
                              // trailing: Text(
                              //   'Cajas: ${report.cajas ?? 0}',
                              //   style: const TextStyle(color: Colors.green),
                              // ),
                              onTap: () {
                                _showReportDetails(context, report);
                              },
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              )
            ],
          ),

          Positioned(
            left: 29.0, // Ajusta la posición horizontal de la lista
            right: 85.0, // Ajusta para reducir el ancho de la lista
            top: 65.0,
            child: Visibility(
              visible: (_searchController.text.isNotEmpty &&
                  _isListUbiVisible &&
                  _filtersubDepartments.length > 0),
              child: Container(
                //width: 1.0, //
                decoration: BoxDecoration(
                  color: Colors.white, // Fondo blanco para la lista
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                        10), // Redondeo solo en la esquina inferior izquierda
                    bottomRight: Radius.circular(
                        10), // Redondeo solo en la esquina inferior derecha
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5), // Sombra gris
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3), // Sombra debajo de la lista
                    ),
                  ],
                ),
                child: SizedBox(
                  height: _filtersubDepartments.length > 3
                      ? 150
                      : _filtersubDepartments.length > 1
                          ? 100
                          : 40,
                  //width: 160,
                  child: ListView.builder(
                    itemCount: _filtersubDepartments.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          ListTile(
                            // contentPadding: EdgeInsets.symmetric(
                            //     vertical: 0.0,
                            //     horizontal:
                            //         6.0), // Reduce el padding vertical
                            title: Text(
                              _filtersubDepartments[index],
                              style: TextStyle(
                                fontSize: 12.0, // Reduce el tamaño de la letra
                              ),
                            ),
                            visualDensity: VisualDensity(vertical: -4),
                            minVerticalPadding: 0,

                            onTap: () {
                              // Filtrar productos por ubicación seleccionada
                              _searchController.text = _filtersubDepartments[
                                  index]; // Establece el texto seleccionado
                              FocusScope.of(context)
                                  .unfocus(); // Cierra el teclado
                              _filterReportsBySupDept(
                                  _filtersubDepartments[index]);
                              _isListUbiVisible = false;
                            },
                          ),
                          if (index != _filtersubDepartments.length - 1)
                            Divider(), // Línea divisoria entre elementos
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          //Aquí están los Positioned
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(10),
                  bottom: Radius.circular(10),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isInfoVisible = !_isInfoVisible;
                            _isSearchVisible = false;
                            _isCodigoVisible = false;
                          });
                        },
                        icon: Icon(Icons.bar_chart),
                        label: Text('Inform'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSearchVisible =
                                !_isSearchVisible; // Mostrar/Ocultar buscador
                            if (_isSearchVisible) {
                              // Cuando se muestre el buscador, abrir automáticamente el teclado
                              _isCodigoVisible = false;
                              _isInfoVisible = false;
                              Future.delayed(Duration(milliseconds: 100), () {
                                FocusScope.of(context).requestFocus(_focusNode);
                              });
                              _isListUbiVisible = true;
                            } else {
                              // Cierra el teclado cuando el buscador se oculta
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          });
                        },
                        icon: Icon(Icons.filter_alt),
                        label: Text('Sub dept'),
                      ),
                    ],
                  ),

                  // TextField(
                  //   controller: _codigoController, // Asocia el controlador
                  //   decoration: InputDecoration(
                  //     labelText: 'Código Escaneado',
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: MediaQuery.of(context).size.width / 2 - 40,
            child: Material(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  color: Colors.white,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BarcodeScannerSimple(),
                      ),
                    );

                    if (result != null) {
                      _isInfoVisible = false;
                      _isSearchVisible = false;
                      _isCodigoVisible = true;
                      // await Future.delayed(
                      //     Duration(milliseconds: 10000)); // Un pequeño retraso
                      setState(() {
                        _codigoController.text =
                            result; // Actualiza el controlador
                      });
                      _filterReports(result);
                      // filterProductos(result);
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exportar Reporte'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Ingrese su nombre',
              hintText: 'Ingrese su nombre',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Cierra el diálogo
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

                  if (nombreUsuario.isNotEmpty) {
                    String filePath =
                        await exportToExcel(reportes, nombreUsuario);

                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.success,
                      animType: AnimType.scale,
                      title: 'Archivo exportado',
                      desc: 'El archivo ha sido guardado en: $filePath',
                      btnOkOnPress: () {
                        Navigator.of(context).pop();
                      },
                    ).show();
                  } else {
                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.warning,
                      animType: AnimType.scale,
                      title: 'Ingrese su Nombre ',
                      desc: 'Es necesario Nombre',
                      btnOkOnPress: () {
                        // Puedes agregar alguna acción extra si lo deseas al presionar "Aceptar"
                        // En este caso, solo cerramos el diálogo.
                      },
                    ).show();
                  }
                },
                child: const Text(
                  'Aceptar',
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
}
