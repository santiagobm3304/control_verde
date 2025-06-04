import 'dart:io';

import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/utils/alerts.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:excel/excel.dart'
    show Sheet, Excel, TextCellValue, IntCellValue, DoubleCellValue;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductosReporteScreen extends StatefulWidget {
  final int selectedTim;

  const ProductosReporteScreen({Key? key, required this.selectedTim})
      : super(key: key);

  @override
  _ProductosReporteScreen createState() => _ProductosReporteScreen();
}

class _ProductosReporteScreen extends State<ProductosReporteScreen> {
  List<Reporte> _productos = [];
  List<Reporte> _productosFiltrados = [];
  String? _descripcionFiltro;
  String? _eanFiltro;
  String? _subDeptFiltro;
  bool _filtrosVisbles = true;
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

  bool activarTodo = false;

  Producto? _productoGenernal;
  // bool _seleccionarTodos = false;

  ReporteTim? reportesInfo;
  TextEditingController _codigoController = TextEditingController();
  TextEditingController _descController = TextEditingController();

  List<String> _subDeptOptions = [];

  final TextEditingController _controllerAddTim = TextEditingController();
  final alert = Alerts.instance;

  double? unidadesAddTim;

  @override
  void initState() {
    super.initState();
    SocketService().init();
    final socket = SocketService().socket;

    socket.on('producto-actualizado', (data) async {
      print('🟡 Producto actualizado desde otro dispositivo: $data');
      await _reCargaProductos();
      _actualizarFiltro();
      // Aquí actualizas tu lista o estado
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarProductos(); // ya se puede usar context
    });
  }

  Future<void> _cargarProductos() async {
    final dialogContext = await loading.instance.showLoadingDialog(context, 'Cargando Productos');

    try {
      final serviceDR = DetalleReporteService();
      final serviceR = ReporteService();
      final productos =
          await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);
      reportesInfo = await serviceR.obtenerReporte(widget.selectedTim);

      if (mounted) {
        setState(() {
          _productos = productos;
          _subDeptOptions =
              productos.map((item) => item.subdpto).toSet().toList();
          _productosFiltrados = productos;
        });
      }
    } catch (error) {
      alert.showErrorDialog(context, 'Error al cargar productos');
    } finally {
      Navigator.pop(dialogContext);
    }
  }

  Future<void> _reCargaProductos() async {
    try {
      final serviceDR = DetalleReporteService();
      final productos = await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);

      setState(() {
        _productos = productos;
        _subDeptOptions = productos
            .map((item) => item.subdpto) // Extraer los subdepartamentos
            .toSet() // Eliminar duplicados
            .toList(); // Conviertir de nuevo a lista
        _productosFiltrados = productos;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  String extraerCodigoCentral(String input) {
    String limpio =
        input.replaceFirst(RegExp(r'^0+'), '').replaceFirst(RegExp(r'0+$'), '');
    if (limpio.length < 8) return limpio;
    int inicio = (limpio.length / 2).floor() - 4;
    return limpio.substring(inicio, inicio + 8);
  }

  void _actualizarFiltro() async {
    setState(() {
      _productosFiltrados = _productos.where((item) {
        bool descripcionMatch = _descripcionFiltro == null ||
            item.descripcion
                .toLowerCase()
                .contains(_descripcionFiltro!.toLowerCase());

        bool subDeptMatch = _subDeptFiltro == null ||
            item.subdpto.toLowerCase().contains(_subDeptFiltro!.toLowerCase());

        bool eanMatch = true;

        if (_eanFiltro != null && _eanFiltro!.isNotEmpty) {
          if (_eanFiltro!.length <= 8) {
            // Buscar por SKU si es corto
            eanMatch = item.sku.contains(_eanFiltro!);
          } else {
            // Buscar por EAN si es largo
            eanMatch = item.ean.contains(_eanFiltro!);
          }
        }

        return descripcionMatch && eanMatch && subDeptMatch;
      }).toList();

      _productosFiltrados
          .sort((a, b) => a.descripcion.compareTo(b.descripcion));
    });

    // Si no encuentra nada, intenta convertir el EAN largo a SKU
    if (_productosFiltrados.isEmpty &&
        _eanFiltro != null &&
        _eanFiltro!.length > 8) {
      final posibleSku = extraerCodigoCentral(_eanFiltro!);

      final encontrados =
          _productos.where((item) => item.sku.contains(posibleSku)).toList();

      if (encontrados.isNotEmpty) {
        setState(() {
          _productosFiltrados = encontrados;
        });
        return;
      }
      final service = ProductoService();
      final productoGenal = await service.obtenerProductoPorCodigo(_eanFiltro!);
      setState(() {
        _productoGenernal = productoGenal;
      });
    }
  }

  Future<void> _cambiarEstadoMasa() async {
    bool confirmar = await _mostrarConfirmacion();
    final serviceDR = DetalleReporteService();
    if (confirmar) {
      for (var producto in _productosFiltrados) {
        bool result;
        //if (activarTodo) {
        // Si activarTodo es true, activamos el switch
        result = await serviceDR.actualizarRecibidos(
            producto.id, producto.uEnviadas);
        //}

        // else {
        //   // Si activarTodo es false, desactivamos el switch
        //   result = await DatabaseHelper.instance
        //       .updateRecibidos(producto.id ?? 0, 0);
        // }

        // Si la actualización fue exitosa, actualizamos el estado del producto
        if (result) {
          setState(() {
            producto.fastRegister = true;
            //  producto.fastRegister = activarTodo;
            producto.uRecibidas = producto.uEnviadas;
          });
        } else {
          _showAlert('Error al actualizar los datos.');
          break;
        }
      }
    }
  }

  Future<bool> _mostrarConfirmacion() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirmación'),
              content: Text(
                  '¿Estás seguro de que quieres  registras todos los productos?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(false); // Regresar false al cerrar el diálogo
                  },
                ),
                TextButton(
                  child: Text('Confirmar'),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(true); // Regresar true al confirmar
                  },
                ),
              ],
            );
          },
        )) ??
        false;
  }

  Future<void> _insertarProductoSobrante(String sku) async {
    try {
      final serviceDR = DetalleReporteService();
      final reporteDR = DetalleReporte(
        id: '',
        tim: widget.selectedTim,
        olpn: 'SOBRANTE',
        sku: sku,
        uEnviadas: 0,
        uRecibidas: unidadesAddTim ?? 0,
        fechavencimiento: '',
        observacion: 'SOBRANTE',
      );
      print(reporteDR);
      await serviceDR.insertarDetalleReporte(reporteDR);
      await _reCargaProductos();
      _actualizarFiltro();
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        headerAnimationLoop: false,
        title: 'Éxito',
        desc: 'El producto fue agregado como sobrante exitosamente.',
        btnOkOnPress: () {},
      ).show();
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        headerAnimationLoop: false,
        title: 'Error !!!!!',
        desc: 'Hubo un problema al agregar el producto como sobrante. $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  void _showReportDetails(BuildContext context, Reporte report) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () async {
            await _reCargaProductos();
            _actualizarFiltro();
          },
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) async {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exportar Reporte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TIM: ${widget.selectedTim}'),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Ingrese nombre de OT',
                  hintText: 'Ingrese nombre de OT',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
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
                    _cargarProductos();
                    String filePath =
                        await exportToExcel(_productos, nombreUsuario);

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
                      title: 'Ingrese su Nombre',
                      desc: 'Es necesario el nombre del Preventor',
                      btnOkOnPress: () {},
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

  Future<String> exportToExcel(List<Reporte> reports, String nombre) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue('Preventores: '), TextCellValue(nombre)]);
    sheet.appendRow([TextCellValue('Tim: '), IntCellValue(widget.selectedTim)]);
    sheet.appendRow(
        [TextCellValue('Placa: '), TextCellValue(reportesInfo?.placa ?? '')]);
    sheet.appendRow([
      TextCellValue('Origen: '),
      TextCellValue(reportesInfo?.localOrigen ?? '')
    ]);
    sheet.appendRow([
      TextCellValue('Destino: '),
      TextCellValue(reportesInfo?.localDestino ?? '')
    ]);
    sheet.appendRow([
      TextCellValue('Fecha envío: '),
      TextCellValue(reportesInfo?.fechaEnvio ?? '')
    ]);

    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('SKU'),
      TextCellValue('Sub Departamento'),
      TextCellValue('Olpn'),
      TextCellValue('Descripción'),
      TextCellValue('Cajas Enviadas'),
      TextCellValue('Uni Enviadas'),
      TextCellValue('Uni Recibidas'),
      TextCellValue('Fecha Vencimiento'),
    ]);

    for (var report in reports) {
      sheet.appendRow([
        TextCellValue(report.sku),
        TextCellValue(report.subdpto),
        TextCellValue(report.olpn),
        TextCellValue(report.descripcion),
        DoubleCellValue(report.uEnviadas / report.casePack),
        DoubleCellValue(report.uEnviadas),
        DoubleCellValue(report.uRecibidas),
        TextCellValue(report.fechavencimiento),
      ]);
    }

    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    String fileName = 'TIM_${widget.selectedTim}_$formattedDate.xlsx';

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
      //print('Archivo guardado en: $filePath');
      return filePath; // Retorna la ubicación del archivo
    } catch (e) {
      return "Error $e";
    }
  }

  void _showOptionsMenu(BuildContext context) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(300, 92, 0, 0),
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Exportar Reporte'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Generar Bitacora'),
        ),
      ],
    );

    switch (result) {
      case 1:
        _showExportDialog(context);
        //_showExportButton = true;

        break;
      case 2:
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Recepción', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
              onPressed: () {
                // setState(() {
                //   activarTodo = !activarTodo;
                // });

                _cambiarEstadoMasa();
              },
              icon: Icon(Icons.check)),
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'TIM:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(widget.selectedTim.toString(),
                    style: TextStyle(fontSize: 18))
              ],
            ),
            SizedBox(height: 15),
            Visibility(
                visible: _filtrosVisbles,
                child: Column(
                  children: [
                    Row(
                      children: [
                        // SizedBox(height: 25),
                        Expanded(
                          child: TextFormField(
                            controller: _descController,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                              labelText: 'Descripción',
                              filled: false,
                              fillColor: Colors.grey[200],
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 8.0),
                              suffixIcon: IconButton(
                                icon: _descripcionFiltro == null ||
                                        _descripcionFiltro!.isEmpty
                                    ? Icon(
                                        Icons.description,
                                        color: Colors.amber,
                                      )
                                    : Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                onPressed: () async {
                                  if (_descripcionFiltro != null ||
                                      _descripcionFiltro!.isEmpty) {
                                    setState(() {
                                      _descController.clear();
                                      _descripcionFiltro = null;
                                      _actualizarFiltro();
                                    });
                                  }
                                },
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _descripcionFiltro = value;
                              });
                              _actualizarFiltro();
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codigoController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: AppColors.amber),
                              ),
                              suffixIcon: IconButton(
                                icon: _eanFiltro == null || _eanFiltro!.isEmpty
                                    ? Icon(
                                        Icons.qr_code,
                                        color: Colors.amber,
                                      )
                                    : Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                onPressed: () async {
                                  if (_eanFiltro == null ||
                                      _eanFiltro!.isEmpty) {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BarcodeScannerSimple(),
                                      ),
                                    );

                                    if (result != null) {
                                      setState(() {
                                        _codigoController.text = result;
                                        _eanFiltro = result.toString().trim();
                                      });
                                      _actualizarFiltro();
                                    }
                                  } else {
                                    setState(() {
                                      _codigoController.clear();
                                      _eanFiltro = null;
                                    });
                                    _actualizarFiltro();
                                  }
                                },
                              ),
                              labelText: 'Sku/Ean',
                              filled: false,
                              fillColor: Colors.grey[200],
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 8.0),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _eanFiltro = value;
                              });
                              _actualizarFiltro();
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Autocomplete<String>(
                            initialValue:
                                TextEditingValue(text: _subDeptFiltro ?? ''),
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                // Mostrar solo los nombres de los subdepartamentos
                                return subDeptMap.keys.toList();
                              }
                              // Filtrar las opciones que coincidan con lo que el usuario escribe
                              return subDeptMap.keys.where((option) {
                                return option.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase());
                              }).toList();
                            },
                            displayStringForOption: (option) => option,
                            onSelected: (selectedOption) {
                              setState(() {
                                _subDeptFiltro = subDeptMap[selectedOption]!;
                              });
                              _actualizarFiltro();
                            },
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'SubDept',
                                  suffixIcon: IconButton(
                                    icon: _subDeptFiltro == null
                                        ? Icon(Icons.arrow_drop_down,
                                            color: Colors.amber)
                                        : Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      if (_subDeptFiltro != null) {
                                        setState(() {
                                          controller.text = "";
                                          _subDeptFiltro = null;
                                        });
                                        _actualizarFiltro();
                                      }
                                    },
                                  ),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 8.0),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _subDeptFiltro = value;
                                  });
                                  _actualizarFiltro();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    // SizedBox(height: 12),
                    // Row(
                    //   children: [
                    //     Text('Seleccionar Todos'),
                    //     Switch(
                    //       value: _seleccionarTodos,
                    //       onChanged: (value) async {
                    //         try {
                    //           // Usamos Future.wait para hacer todas las actualizaciones en paralelo
                    //           List<Future> updateTasks = [];

                    //           // Recorrer todos los productos y crear las tareas para actualizar
                    //           for (var producto in _productosFiltrados) {
                    //             bool result = value
                    //                 ? await DatabaseHelper.instance
                    //                     .updateRecibidos(
                    //                         producto.id ?? 0, producto.unidades)
                    //                 : await DatabaseHelper.instance
                    //                     .updateRecibidos(producto.id ?? 0, 0);

                    //             // Agregar la tarea al list de tareas
                    //             updateTasks.add(
                    //               Future.delayed(Duration.zero, () {
                    //                 if (result) {
                    //                   setState(() {
                    //                     producto.fastRegister = value;
                    //                     producto.recibidos =
                    //                         value ? producto.unidades : 0;
                    //                   });
                    //                 } else {
                    //                   _showAlert(
                    //                       'Error al actualizar los datos.');
                    //                 }
                    //               }),
                    //             );
                    //           }

                    //           // Esperar a que todas las tareas se completen
                    //           await Future.wait(updateTasks);
                    //           if (value) {
                    //             setState(() {
                    //               _seleccionarTodos = true;
                    //             });
                    //           } else {
                    //             setState(() {
                    //               _seleccionarTodos = false;
                    //             });
                    //           }

                    //         } catch (e) {
                    //           // Si ocurre un error inesperado, mostramos una alerta.
                    //           _showAlert('Ocurrió un error: $e');
                    //         }
                    //       },
                    //     ),
                    //   ],
                    // ),

                    SizedBox(height: 12),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.start,
                    //   children: [
                    //     Text('Fecha Vecimiento: '),
                    //   ],
                    // ),
                    // SizedBox(height: 4),
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: TextFormField(
                    //         controller: _dateDesdeController,
                    //         readOnly: true,
                    //         decoration: InputDecoration(
                    //           labelText: " Desde",
                    //           suffixIcon: IconButton(
                    //               icon: _dateDesdeController.text.isEmpty
                    //                   ? Icon(
                    //                       Icons.calendar_today,
                    //                       color: Colors.amber,
                    //                     )
                    //                   : Icon(
                    //                       Icons.close,
                    //                       color: Colors.red,
                    //                     ),
                    //               onPressed: () async {
                    //                 if (_dateDesdeController.text.isNotEmpty) {
                    //                   _dateDesdeController.clear();
                    //                   _selectedDesdeDate = null;
                    //                   _actualizarFiltro();
                    //                 } else {
                    //                   _selectDesdeDate(context);
                    //                 }
                    //               }),
                    //           border: OutlineInputBorder(),
                    //           contentPadding: EdgeInsets.symmetric(
                    //               vertical: 8.0, horizontal: 8.0),
                    //         ),
                    //         onTap: () => _selectDesdeDate(context),
                    //       ),
                    //     ),
                    //     SizedBox(width: 10),
                    //     Expanded(
                    //       child: TextFormField(
                    //         controller: _dateHastaController,
                    //         readOnly: true,
                    //         decoration: InputDecoration(
                    //           labelText: "Hasta ",
                    //           suffixIcon: IconButton(
                    //             icon: _dateHastaController.text.isEmpty
                    //                 ? Icon(
                    //                     Icons.calendar_today,
                    //                     color: Colors.amber,
                    //                   )
                    //                 : Icon(Icons.close, color: Colors.red),
                    //             onPressed: () async {
                    //               if (_dateHastaController.text.isNotEmpty) {
                    //                 _dateHastaController.clear();
                    //                 _selectedHastaDate = null;
                    //                 _actualizarFiltro();
                    //               } else {
                    //                 _selectHastaDate(context);
                    //               }
                    //             },
                    //           ),
                    //           border: OutlineInputBorder(),
                    //           contentPadding: EdgeInsets.symmetric(
                    //               vertical: 8.0, horizontal: 8.0),
                    //         ),
                    //         onTap: () => _selectHastaDate(context),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                )),
            Expanded(
              child: _productosFiltrados.isEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No se encontraron productos en la TIM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 28),
                          if (_productoGenernal != null)
                            Card(
                              elevation: 6,
                              color: Colors.blue[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Producto Encontrado en Profundidad:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      ' ${_productoGenernal!.descripcion}',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Proveedor: ${_productoGenernal!.proveedor}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'SubDpto: ${_productoGenernal!.subdpto}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          'SKU: ${_productoGenernal!.sku}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'EAN: ${_productoGenernal!.ean}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Case Pack: ${_productoGenernal!.casePack}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 12,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _controllerAddTim,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Unidades Contadas',
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                unidadesAddTim =
                                                    double.tryParse(value);
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: 15,
                                        ),
                                        TextButton.icon(
                                          onPressed: () async {
                                            if (unidadesAddTim != null &&
                                                unidadesAddTim! > 0 &&
                                                _productoGenernal != null) {
                                              await _insertarProductoSobrante(
                                                  _productoGenernal!.sku);
                                              _controllerAddTim.clear();
                                            } else {
                                              AwesomeDialog(
                                                context: context,
                                                dialogType: DialogType.error,
                                                headerAnimationLoop: false,
                                                title: 'Error',
                                                desc:
                                                    'Por favor, ingresa un valor mayor a 0 para las unidades contadas.',
                                                btnOkOnPress: () {},
                                              ).show();
                                            }
                                          },
                                          label: const Text(
                                            'Agregar a la TIM',
                                            style: TextStyle(
                                                color: AppColors.white),
                                          ),
                                          //icon: Icon(Icons.add),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppColors.verdeOs,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Se agregará automáticamente a la TIM como sobrante.',
                                      style: TextStyle(fontSize: 10),
                                    )
                                  ],
                                ),
                              ),
                            )
                          else
                            Card(
                              elevation: 6,
                              color: Colors.blue[50],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Se recomienda actualizar su profundidad',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            height: _filtrosVisbles ? 500 : 615,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            producto.descripcion.trim(),
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Switch(
                                            value: producto.fastRegister, //
                                            activeColor: AppColors.verdeClaro,
                                            onChanged: (value) async {
                                              try {
                                                final serviceDR =
                                                    DetalleReporteService();
                                                if (value) {
                                                  bool result = await serviceDR
                                                      .actualizarRecibidos(
                                                          producto.id,
                                                          producto.uEnviadas);
                                                  if (result) {
                                                    setState(() {
                                                      producto.fastRegister =
                                                          true;
                                                      producto.uRecibidas =
                                                          producto.uEnviadas;
                                                    });
                                                  } else {
                                                    _showAlert(
                                                        'Error al actualizar los datos.');
                                                  }
                                                } else {
                                                  final serviceDR =
                                                      DetalleReporteService();
                                                  bool result = await serviceDR
                                                      .actualizarRecibidos(
                                                          producto.id, 0);
                                                  if (result) {
                                                    setState(() {
                                                      producto.uRecibidas = 0;
                                                      producto.fastRegister =
                                                          false;
                                                    });
                                                  } else {
                                                    _showAlert(
                                                        'Error al actualizar los datos.');
                                                  }
                                                }
                                              } catch (e) {
                                                _showAlert(
                                                    'Ocurrió un error: $e');
                                              }
                                            })
                                      ],
                                    ),
                                    subtitle: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Sku:  ${producto.sku}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: 'SubDpto: ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.subdpto}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
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
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: 'Cajas: ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.uEnviadas / producto.casePack}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      RichText(
                                                        text: TextSpan(
                                                          children: [
                                                            const TextSpan(
                                                              text:
                                                                  'Case Pack: ',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text:
                                                                  '${producto.casePack.toString()}',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
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
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  RichText(
                                                    text: TextSpan(
                                                      children: [
                                                        const TextSpan(
                                                          text: 'Unidades: ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.uEnviadas}',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
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
                                                                text:
                                                                    'Registradas: ',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    '${producto.uRecibidas.toString()}',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
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
                                                                  producto
                                                                      .uEnviadas
                                                              ? Icons.check
                                                              : Icons.warning,
                                                          color: producto
                                                                      .uRecibidas ==
                                                                  producto
                                                                      .uEnviadas
                                                              ? Colors.green
                                                              : producto.uRecibidas >
                                                                          0 &&
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
                                                  //             .green // Verde cuando las unidades coinciden
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
                                height: 40,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                margin: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
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
                                    Text(
                                      'Cajas: ${(_productosFiltrados.fold(0.0, (previousValue, producto) => previousValue + (producto.uEnviadas / producto.casePack)).toStringAsFixed(2))}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Container(
                                height: 40, // Altura del contenedor
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        20), // Agregar padding horizontal
                                margin: EdgeInsets.all(
                                    10), // Margen alrededor del contenedor
                                decoration: BoxDecoration(
                                  color: Colors
                                      .blue, // Color de fondo del contenedor
                                  borderRadius: BorderRadius.circular(
                                      15), // Bordes redondeados
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26, // Sombra sutil
                                      blurRadius: 8, // Difusión de la sombra
                                      offset: Offset(
                                          0, 4), // Dirección de la sombra
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // Centrado horizontal
                                  crossAxisAlignment: CrossAxisAlignment
                                      .center, // Centrado vertical
                                  children: [
                                    // Icon(Icons.info_outline,
                                    //     color: Colors.white), // Icono al inicio
                                    // SizedBox(
                                    //     width: 8), // Espacio entre el icono y el texto
                                    Text(
                                      'Productos: ${_productosFiltrados.length}', // El texto que muestra el total
                                      style: TextStyle(
                                        color: Colors
                                            .white, // Color blanco para el texto
                                        fontSize: 14, // Tamaño de la fuente
                                        fontWeight: FontWeight
                                            .bold, // Hacer el texto en negrita
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlert(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Error',
      desc: message,
      btnOkOnPress: () {},
      btnOkText: 'OK',
    )..show();
  }
}
