import 'dart:io';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/inicio_screeen.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/screens/producto/nuevoproducto_screen.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:excel/excel.dart'
    show Sheet, Excel, TextCellValue, DoubleCellValue;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProductListScreen extends StatefulWidget {
  final int selectedTim;
  const ProductListScreen({required this.selectedTim});
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
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
    'Vestuario': 'J08',
    'Hogar': 'J09',
    'Bazar': 'J10',
    'Muebles': 'J090204',
    'Electro': 'J11'
  };
  // bool activarTodo = false;
  Producto? _productoGenernal;
  List<ReporteTim> reportesInfo = [];
  List<String> _subDeptOptions = [];
  final TextEditingController _controllerAddTim = TextEditingController();
  double? unidadesAddTim;
  final TextEditingController _codigoController = TextEditingController();
  TextEditingController _descController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final productos =
          await DatabaseHelper.instance.getReportesByTim(widget.selectedTim);
      final reporteInfo =
          await DatabaseHelper.instance.getReporteTimByTim(widget.selectedTim);
      setState(() {
        _productos = productos;
        _subDeptOptions =
            productos.map((item) => item.subdpto).toSet().toList();
        _productosFiltrados = productos;
        reportesInfo = reporteInfo;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  Future<void> _reCargaProductos() async {
    try {
      final productos =
          await DatabaseHelper.instance.getReportesByTim(widget.selectedTim);

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

  void _actualizarFiltro() async {
    setState(() {
      _productosFiltrados = _productos.where((item) {
        bool descripcionMatch = _descripcionFiltro == null ||
            item.descripcion
                .toLowerCase()
                .contains(_descripcionFiltro!.toLowerCase());
        bool eanMatch = _eanFiltro == null || _eanFiltro!.length <= 8
            ? item.sku.contains(_eanFiltro ?? '')
            : item.ean.contains(_eanFiltro ?? '');
        bool subDeptMatch = _subDeptFiltro == null ||
            item.subdpto.toLowerCase().contains(_subDeptFiltro!.toLowerCase());
        return descripcionMatch && eanMatch && subDeptMatch;
      }).toList();
      _productosFiltrados
          .sort((a, b) => a.descripcion.compareTo(b.descripcion));
    });

    if (_productosFiltrados.isEmpty) {
      final productoGenal =
          await DatabaseHelper.instance.getProductobyEan(_eanFiltro ?? '');
      setState(() {
        _productoGenernal = productoGenal;
      });
    }
  }

  Future<void> _insertarProductoSobrante(Producto productoSobrante) async {
    try {
      final reporte = Reporte(
        ean: productoSobrante.ean,
        olpn: 'DONACION',
        tim: widget.selectedTim,
        descripcion: productoSobrante.descripcion,
        subdpto: productoSobrante.subdpto,
        sku: productoSobrante.sku,
        casePack: productoSobrante.casePack,
        uMedida: productoSobrante.uMedida,
        precioVigente: productoSobrante.precioVigente,
        costoPromedio: productoSobrante.costoPromedio,
        uEnviadas: 0,
        cEnviadas: 0,
        uRecibidas: unidadesAddTim ?? 0,
        fechavencimiento: '',
        faltantes: '0',
      );
      await DatabaseHelper.instance.insertReportSinR(reporte);
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
        title: 'Error',
        desc: 'Hubo un problema al agregar el producto como sobrante. $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  void _showReportDetails(BuildContext context, Reporte report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () async {
            await _reCargaProductos();
            _actualizarFiltro();
            // reportes = await _loadReports();
            // _filterReports("");
          },
        );
      },
    );
  }

  Future<bool> _mostrarConfirmacion() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirmación'),
              content: Text(
                  '¿Estás seguro de que quieres eliminar el registro de las donaciones?'),
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
                    _deleteDonacion(context, widget.selectedTim);
                  },
                ),
              ],
            );
          },
        )) ??
        false; // Si showDialog retorna null, retornamos false por defecto
  }

  void _deleteDonacion(BuildContext context, int tim) async {
    try {
      await DatabaseHelper.instance.deleteReportes(tim);
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        headerAnimationLoop: false,
        title: 'Éxito',
        desc: 'El registro de donaciones fue eliminado exitosamente.',
        btnOkOnPress: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InicioScreen(),
            ),
          );
        },
      ).show();
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        headerAnimationLoop: false,
        title: 'Error',
        desc: '',
        btnOkOnPress: () {},
      ).show();
    }
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
              Text('DONACIÓN: ${widget.selectedTim}'),
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
    excel.delete('Sheet1');
    String formattedDate = DateFormat('dd-MM-yy').format(DateTime.now());
    Sheet sheet = excel['Donaciones'];
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow(
        [TextCellValue('FORMATO - SOLICITUD DE ENTREGA DE DONACIONES')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Colaborador: '), TextCellValue(nombre)]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Fecha: '), TextCellValue(formattedDate)]);

    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('N'),
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('FECHA VENCIMIENTO'),
      TextCellValue('CRITERIO DONACION'),
      TextCellValue('UNIDAD MEDIDA'),
      TextCellValue('CANTIDAD'),
    ]);
    int contador = 1;
    for (var report in reports) {
      sheet.appendRow([
        TextCellValue(contador.toString()),
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        TextCellValue(report.fechavencimiento),
        TextCellValue('BAP'),
        TextCellValue(report.uMedida),
        DoubleCellValue(report.uRecibidas),
      ]);
      contador++;
    }

    String fileName = 'donacion $formattedDate.xlsx';

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

  void _showOptionsMenu(BuildContext context) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(300, 92, 0, 0),
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Exportar Donación'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Nuevo Producto'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text('Vaciar Donación'),
        ),
      ],
    );

    switch (result) {
      case 1:
        _showExportDialog(context);
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgregarProductoScreen(),
          ),
        );
        break;
      case 3:
        _mostrarConfirmacion();
        break;
    }
  }

  void _eliminarProducto(Reporte producto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar este producto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteReporte(widget.selectedTim,
            producto.ean); // Asegúrate que esta función exista

        setState(() {
          _productos.removeWhere((p) => p.id == producto.id);
          _productosFiltrados.removeWhere((p) => p.id == producto.id);
        });

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.rightSlide,
          title: 'Producto eliminado',
          desc: 'El producto fue eliminado exitosamente.',
          btnOkOnPress: () {},
        ).show();
      } catch (e) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.leftSlide,
          title: 'Error',
          desc: 'No se pudo eliminar el producto.',
          btnOkOnPress: () {},
        ).show();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.verdeClaro,
          title: Text(
            'Donaciones - ${widget.selectedTim.toString()}',
            style: TextStyle(color: AppColors.white),
          ),
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
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptionsMenu(context),
            ),
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.all(8.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                  borderSide:
                                      BorderSide(color: AppColors.amber),
                                ),
                                suffixIcon: IconButton(
                                  icon:
                                      _eanFiltro == null || _eanFiltro!.isEmpty
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
                                          : Icon(Icons.close,
                                              color: Colors.red),
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
                              'No se encontraron productos en el registro',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Registrar producto:',
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
                                      Text(
                                        'Costo Promedio: ${_productoGenernal!.costoPromedio}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _controllerAddTim,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Cantidad',
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  unidadesAddTim =
                                                      double.parse(value);
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(
                                            width: 15,
                                          ),
                                          TextButton.icon(
                                            onPressed: () {
                                              if (unidadesAddTim != null &&
                                                  unidadesAddTim! > 0 &&
                                                  _productoGenernal != null) {
                                                _insertarProductoSobrante(
                                                    _productoGenernal!);
                                              } else {
                                                AwesomeDialog(
                                                  context: context,
                                                  dialogType: DialogType.error,
                                                  headerAnimationLoop: false,
                                                  title: 'Error',
                                                  desc: 'Agregue una cantidad.',
                                                  btnOkOnPress: () {},
                                                ).show();
                                              }
                                            },
                                            label: const Text(
                                              'Agregar producto',
                                              style: TextStyle(
                                                  color: AppColors.white),
                                            ),
                                            //icon: Icon(Icons.add),
                                            style: TextButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.verdeOs,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Se agregará automáticamente al registro.',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              (producto.descripcion).trim(),
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _eliminarProducto(producto),
                                            tooltip: 'Eliminar producto',
                                          ),
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
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                '${producto.subdpto}',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color: Colors
                                                                    .black),
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
                                                            text: 'Cantidad: ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                '${producto.uRecibidas}',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          const TextSpan(
                                                            text:
                                                                'Fecha Vencimiento: ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                '${producto.fechavencimiento}',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color: Colors
                                                                    .black),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () =>
                                          _showReportDetails(context, producto),
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
                                    mainAxisAlignment: MainAxisAlignment
                                        .center, // Centrado horizontal
                                    crossAxisAlignment: CrossAxisAlignment
                                        .center, // Centrado vertical
                                    children: [
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
              SizedBox(height: 20),
            ])));
  }
}
