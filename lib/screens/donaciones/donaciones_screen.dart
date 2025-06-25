import 'dart:io';

import 'package:control_verde/inicio_screeen.dart';
import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/utils/alerts.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/screens/producto/nuevoproducto_screen.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
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
    'Verduras ': 'J040102',
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
  ReporteTim? reportesInfo;
  List<String> _subDeptOptions = [];
  final TextEditingController _controllerAddTim = TextEditingController();
  double? unidadesAddTim;
  final alert = Alerts.instance;
  final TextEditingController _codigoController = TextEditingController();
  TextEditingController _descController = TextEditingController();
  @override
  void initState() {
    super.initState();
    SocketService().joinSala(widget.selectedTim.toString());

    final socket = SocketService().socket;
    SocketService().onReconectado = _recargarVista;

    socket.on('producto-agregado', (data) {
      if (!mounted) return;
      print(data);
      final nuevoProducto = Reporte.fromJson(data);
      print(nuevoProducto);
      setState(() {
        _productos.add(nuevoProducto);
      });
      _actualizarFiltro();
    });

    socket.on('producto-eliminado', (data) {
      if (!mounted) return;
      print(data);
      final id = data;
      setState(() {
        _productos.removeWhere((p) => p.id == id);
      });
      _actualizarFiltro();
    });

    socket.on('producto-actualizado', (data) {
      if (!mounted) return;
      final id = data['_id'];
      final nuevasURecibidas = double.tryParse(data['uRecibidas'].toString());

      if (nuevasURecibidas == null) return;

      final index = _productos.indexWhere((p) => p.id == id);
      if (index != -1) {
        setState(() {
          _productos[index].uRecibidas = nuevasURecibidas;
          _productos[index].fastRegister = nuevasURecibidas > 0;
          print(_productos[index].uRecibidas);
        });
      }
      _actualizarFiltro();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarProductos();
    });
  }

  @override
  void dispose() {
    SocketService().leaveSala();
    super.dispose();
  }

  void _recargarVista() async {
    print('♻️ Vista recargada por reconexión');
    await _cargarProductos();
    _actualizarFiltro();
  }

  Future<void> _cargarProductos() async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Cargando Productos');

    try {
      final serviceDR = DetalleReporteService();
      final serviceR = ReporteService();

      final productos =
          await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);
      reportesInfo = await serviceR.obtenerReporte(widget.selectedTim);
      setState(() {
        _productos = productos;
        _subDeptOptions =
            productos.map((item) => item.subdpto).toSet().toList();
        _productosFiltrados = productos;
      });
    } catch (error) {
      alert.showErrorDialog(context, 'Error al cargar productos');
    } finally {
      Navigator.pop(dialogContext);
    }
  }

  // Future<void> _reCargaProductos() async {
  //   try {
  //     final serviceDR = DetalleReporteService();
  //     final productos =
  //         await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);

  //     setState(() {
  //       _productos = productos;
  //       _subDeptOptions =
  //           productos.map((item) => item.subdpto).toSet().toList();
  //       _productosFiltrados = productos;
  //     });
  //   } catch (error) {
  //     print('Error al cargar productos: $error');
  //   }
  // }

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
        final descripcionMatch = _descripcionFiltro == null ||
            (item.descripcion
                .toLowerCase()
                .contains(_descripcionFiltro!.toLowerCase()));

        final subDeptMatch = _subDeptFiltro == null ||
            (item.subdpto
                .toLowerCase()
                .contains(_subDeptFiltro!.toLowerCase()));

        bool eanMatch = true;
        if (_eanFiltro != null && _eanFiltro!.isNotEmpty) {
          eanMatch = item.sku.contains(_eanFiltro!);
          if (!eanMatch) {
            eanMatch = item.ean.contains(_eanFiltro!);
          }
        }

        return descripcionMatch && eanMatch && subDeptMatch;
      }).toList();

      _productosFiltrados
          .sort((a, b) => a.descripcion.compareTo(b.descripcion));
    });

    if (_productosFiltrados.isEmpty && _eanFiltro != null) {
      final posibleSku = extraerCodigoCentral(_eanFiltro!);
      if (posibleSku.isNotEmpty) {
        final encontrados =
            _productos.where((item) => item.sku.contains(posibleSku)).toList();

        if (encontrados.isNotEmpty) {
          setState(() {
            _productosFiltrados = encontrados;
          });
          return;
        }
      }

      final service = ProductoService();
      final productoGenal = await service.obtenerProductoPorCodigo(_eanFiltro!);
      setState(() {
        _productoGenernal = productoGenal;
        _productosFiltrados = [];
      });
    }
  }

  Future<void> _insertarProductoSobrante(Producto productoSobrante) async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Agregando producto');
    try {
      final serviceDR = DetalleReporteService();
      final reporteDR = DetalleReporte(
        id: '',
        tim: widget.selectedTim,
        olpn: 'DONACION',
        sku: productoSobrante.sku,
        uEnviadas: 0,
        uRecibidas: unidadesAddTim ?? 0,
        fechavencimiento: '',
        observacion: 'DONACION',
      );
      Reporte result = await serviceDR.insertarDetalleReporte(
          reporteDR, widget.selectedTim.toString());
      print(result);
      setState(() {
        _productos.add(result);
      });
      _actualizarFiltro();
      Navigator.pop(dialogContext);
      alert.showSuccessDialog(context, "Se agregó el producto como sobrante");
    } catch (e) {
      Navigator.pop(dialogContext);
      alert.showErrorDialog(
          context, "Hubo un error al agregar el producto como sobrante");
    }
  }

  void _showReportDetails(BuildContext context, Reporte report) async {
    final Reporte? result = await showDialog<Reporte>(
      context: context,
      builder: (BuildContext context) {
        return ReportDetailsDialog(
          report: report,
          onSave: () {},
        );
      },
    );
    if (result != null) {
      final dialogContext = await loading.instance
          .showLoadingDialog(context, "Actualizando Datos");
      final index = _productos.indexWhere((p) => p.id == result.id);
      print(result);
      print(index);
      if (index != -1) {
        setState(() {
          _productos[index] = result;
          _actualizarFiltro();
          print(_productos[index]);
        });
        Navigator.pop(dialogContext);
        return;
      }
      Navigator.pop(dialogContext);
    }
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
                    Navigator.of(context).pop(false);
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
        false;
  }

  void _deleteDonacion(BuildContext context, int tim) async {
    final dialogContext = await loading.instance
        .showLoadingDialog(context, "Eliminando Donación");
    try {
      final serviceR = ReporteService();
      await serviceR.eliminarTim(tim);
      Navigator.pop(dialogContext);
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InicioScreen(),
          ));

      alert.showSuccessDialog(context, "La donación se eliminó correctamente");
    } catch (e) {
      Navigator.pop(dialogContext);
      alert.showErrorDialog(context, "Hubo un error al eliminar la donación");
    }
  }

  void _showExportDialog(BuildContext context) async {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogcontext) {
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
                    await _cargarProductos();
                    await exportToExcel(_productos, nombreUsuario);
                    Navigator.of(dialogcontext).pop();
                    alert.showSuccessDialog(
                        context, "El archivo se exportó correctamente.");
                  } else {
                    alert.showErrorDialog(
                        context, "Por favor, ingrese un nombre válido.");
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
    final dialogContext =
        await loading.instance.showLoadingDialog(context, "Exportando a Excel");
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

    String fileName = 'DONACION $formattedDate.xlsx';
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
    } finally {
      Navigator.pop(dialogContext);
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
      final dialogContext = await loading.instance
          .showLoadingDialog(context, "Eliminando producto");
      try {
        final serviceDR = DetalleReporteService();
        await serviceDR.eliminarDetalleReporte(producto.id,
            widget.selectedTim.toString()); // Asegúrate que esta función exista

        setState(() {
          _productos.removeWhere((p) => p.id == producto.id);
        });
        _actualizarFiltro();
        Navigator.pop(dialogContext);
        alert.showSuccessDialog(
            context, "El producto fue eliminado exitosamente.");
      } catch (e) {
        Navigator.pop(dialogContext);
        alert.showErrorDialog(context, "Hubo un error al eliminar el producto");
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
                              keyboardType: TextInputType.number,
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
                                        _productoGenernal = null;

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
                                            onPressed: () async {
                                              if (unidadesAddTim != null &&
                                                  unidadesAddTim! > 0 &&
                                                  _productoGenernal != null) {
                                                await _insertarProductoSobrante(
                                                    _productoGenernal!);

                                                _controllerAddTim.clear();
                                                _productoGenernal = null;
                                              } else {
                                                alert.showErrorDialog(
                                                  context,
                                                  "Debe ingresar una cantidad válida para agregar el producto.",
                                                );
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
                                        'Escanee un producto para agregarlo.',
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
