import 'dart:convert';
import 'dart:io';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/utils/alerts.dart';
import 'package:control_verde/utils/inventario_perecibles_detalle.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/utils/unauthorized.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:excel/excel.dart'
    show Sheet, Excel, TextCellValue, IntCellValue, DoubleCellValue;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class InventarioPerecibles extends StatefulWidget {
  final int selectedInventario;

  const InventarioPerecibles({Key? key, required this.selectedInventario})
      : super(key: key);

  @override
  _PereciblesDetalleScreen createState() => _PereciblesDetalleScreen();
}

class _PereciblesDetalleScreen extends State<InventarioPerecibles> {
  List<Reporte> _productos = [];
  List<Reporte> _productosFiltrados = [];
  String? _descripcionFiltro;
  String? _eanFiltro;
  bool _filtrosVisbles = true;
  bool activarTodo = false;
  String? _subDeptFiltro;
  Producto? _productoGenernal;

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
    'Pizzas': 'J070109'
  };

  ReporteTim? reportesInfo;
  final alert = Alerts.instance;

  // TextEditingController _dateDesdeController = TextEditingController();
  // TextEditingController _dateHastaController = TextEditingController();
  TextEditingController _codigoController = TextEditingController();
  TextEditingController _descController = TextEditingController();
  // DateTime? _selectedDesdeDate;
  // DateTime? _selectedHastaDate;
  final serviceP = ProductoService();
  final dataBaseH = DatabaseHelper.instance;
  String? nombre;
  final TextEditingController _controllerAddTim = TextEditingController();
  final UserRepository _userRepo = UserRepository();

  late double cajaAddOlpn = 0;
  List<int> olpnsUnicos = [];
  double? unidadesAddTim;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await sincronizarProductos();
      await _cargarProductos();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> sincronizarProductos() async {
    if (!mounted) return;

    final dialogContext = await loading.instance.showLoadingDialog(
      context,
      'Sincronizando Productos, por favor manténgase conectado a internet.',
    );

    try {
      final productos = await serviceP.fetchProductosDesdeBackend(context);

      if (!mounted) return;
      await dataBaseH.guardarProductosLocal(productos);

      // 🔴 Cerrar loading primero
      Navigator.of(dialogContext, rootNavigator: true).pop();

      // ✅ Luego mostrar modal de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Productos sincronizados con éxito')),
        );
      }
    } on UnauthorizedException catch (e) {
      if (mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, stack) {
      debugPrint('❌ Error real: $e');
      debugPrintStack(stackTrace: stack);

      if (mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Error al sincronizar productos")),
        );
      }
    }
  }

  Future<Directory?> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    }
    return null;
  }

  Future<void> _cargarProductos() async {
    try {
      final productos =
          await dataBaseH.getReportesByTim(widget.selectedInventario);
      final reporteInfo =
          await dataBaseH.getReporteTimByTim(widget.selectedInventario);
      final user = await _userRepo.getUser();
      setState(() {
        _productos = productos;
        reportesInfo = reporteInfo;
        _productosFiltrados = productos;
        nombre = user?.nombre ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cargo ${productos.length} productos")),
      );
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  Future<void> _reCargaProductos() async {
    try {
      final productos =
          await dataBaseH.getReportesByTim(widget.selectedInventario);

      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  String extraerCodigoCentral(String input) {
    String limpio = input.replaceFirst(RegExp(r'^0+'), '');
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
          if (_eanFiltro!.length == 8) {
            eanMatch = item.sku.contains(_eanFiltro!);
            if (!eanMatch) {
              eanMatch = item.ean.contains(_eanFiltro!);
            }
          } else {
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

      final productoGenal =
          await dataBaseH.buscarProductoPorCodigo(_eanFiltro!);
      setState(() {
        _productoGenernal = productoGenal;
        _productosFiltrados = [];
      });
    }
  }

  Future<void> _insertarProductoSobrante(Producto productoSobrante) async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Agregando Producto');
    try {
      if (!mounted) return;
      final reporteDR = Reporte(
        id: '',
        olpn: 'INVENTARIO',
        tim: widget.selectedInventario,
        subdpto: productoSobrante.subdpto,
        sku: productoSobrante.sku,
        ean: productoSobrante.ean,
        descripcion: productoSobrante.descripcion,
        casePack: productoSobrante.casePack,
        uMedida: productoSobrante.uMedida,
        precioVigente: productoSobrante.precioVigente,
        costoPromedio: productoSobrante.costoPromedio,
        uEnviadas: 0,
        uRecibidas: unidadesAddTim ?? 0,
        fechavencimiento: '--',
        isContable: productoSobrante.isContable,
        marcaSensible: productoSobrante.marcaSensible,
        modificadoPor: nombre,
        observacion: 'AGREGADO',
      );
      await dataBaseH.insertReport(reporteDR);
      await _reCargaProductos();
      Navigator.pop(dialogContext);
      _codigoController.clear();
      _actualizarFiltro();
      alert.showSuccessDialog(context, "Se agregó el producto correctamente");
    } catch (e) {
      Navigator.pop(dialogContext);
      alert.showErrorDialog(context, e.toString());
    }
  }

  void _showReportDetails(BuildContext context, Reporte report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return InventarioPereciblesDialog(
          report: report,
          motivo: 'IP',
          onSave: () async {
            await _reCargaProductos();
            _actualizarFiltro();
          },
        );
      },
    );
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
        await dataBaseH.deleteReporte(producto.sku, producto.tim!);
        await _reCargaProductos();

        alert.showSuccessDialog(
            context, "El producto ha sido eliminado correctamente");
      } catch (e) {
        alert.showErrorDialog(
            context, "El producto no pudo ser eliminado. Intente nuevamente.");
      }
    }
  }

  Future<void> exportAndShareCSV(List<Reporte> reports, String nombre) async {
    try {
      // Construir el contenido CSV
      final buffer = StringBuffer();

      // Encabezado informativo
      buffer.writeln('Preventores:;$nombre');
      buffer.writeln('Inventario:;${reportesInfo!.tim}');
      buffer.writeln('Origen:;${reportesInfo!.localOrigen ?? ''}');
      buffer.writeln('Fecha Registro:;${reportesInfo!.fechaEnvio ?? ''}');
      buffer.writeln('');

      // Cabeceras de columnas
      buffer.writeln(
        'INVENTARIO;EAN;SKU;Descripción;Unidades;Costo Promedio;Total Costo;SubDpto;Case Pack;Fecha Vencimiento',
      );

      // Filas de datos
      for (var report in reports) {
        final totalCosto = report.uRecibidas * report.costoPromedio;
        // Escapar punto y coma dentro de descripciones por si acaso
        final descripcion = report.descripcion.replaceAll(';', ',');
        buffer.writeln(
          '${report.tim};${report.ean};${report.sku};$descripcion;'
          '${report.uRecibidas};${report.costoPromedio};$totalCosto;'
          '${report.subdpto};${report.casePack};${report.fechavencimiento}',
        );
      }

      // Guardar en directorio temporal de la app (no requiere permisos)
      final dir = await getTemporaryDirectory();
      final formattedDate =
          DateFormat('dd-MM-yy_HH-mm-ss').format(DateTime.now());
      final fileName = 'PERECIBLES_${reportesInfo!.tim}_$formattedDate.csv';
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      // UTF-8 con BOM para que Excel lo abra correctamente con tildes
      await file
          .writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);

      // Compartir usando el share sheet nativo
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'text/csv')],
        subject: 'Inventario Perecibles - ${reportesInfo!.tim}',
      );
    } catch (e) {
      alert.showErrorDialog(context, 'Error al compartir: $e');
    }
  }

  Future<String> exportToExcel(List<Reporte> reports, String nombre) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    sheet.appendRow([TextCellValue('Preventores:'), TextCellValue(nombre)]);
    sheet.appendRow(
        [TextCellValue('Inventario:'), IntCellValue(reportesInfo!.tim)]);
    sheet.appendRow(
        [TextCellValue('Origen:'), TextCellValue(reportesInfo!.localOrigen!)]);
    sheet.appendRow([
      TextCellValue('Fecha Registro:'),
      TextCellValue(reportesInfo!.fechaEnvio!)
    ]);

    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('INVENTARIO'),
      TextCellValue('EAN'),
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('Unidades'),
      TextCellValue('Costo Promedio'),
      TextCellValue('Total Costo'),
      TextCellValue('SubDpto'),
      TextCellValue('Case Pack'),
      TextCellValue('Fecha Vencimiento'),
    ]);

    for (var report in reports) {
      sheet.appendRow([
        IntCellValue(report.tim!),
        TextCellValue(report.ean),
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        DoubleCellValue(report.uRecibidas),
        DoubleCellValue(report.costoPromedio),
        DoubleCellValue(report.uRecibidas * report.costoPromedio),
        TextCellValue(report.subdpto),
        IntCellValue(report.casePack),
        TextCellValue(report.fechavencimiento),
      ]);
    }

    final formattedDate =
        DateFormat('dd-MM-yy_HH-mm-ss').format(DateTime.now());

    final fileName = 'PERECIBLES_${reportesInfo!.tim}_$formattedDate.xlsx';

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();

        final directory = Directory('/storage/emulated/0/Download');
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        await file.writeAsBytes(excel.save()!);

        return filePath;
      }

      // iOS fallback
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.save()!);

      return filePath;
    } catch (e) {
      return 'Error: $e';
    }
  }

  void _showOptionsMenu(BuildContext context) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(300, 92, 0, 0),
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Exportar Registro'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Compartir como CSV'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text('Eliminar Registro'),
        ),
      ],
    );

    switch (result) {
      case 1:
        if (nombre == null || nombre!.isEmpty) {
          alert.showWarningDialog(
            context,
            "No se encontró el nombre del usuario",
          );
          return;
        }

        await exportToExcel(_productos, nombre!);

        alert.showSuccessDialog(
          context,
          "El archivo se exportó correctamente a Descargas",
        );
        break;
      case 2:
        if (nombre == null || nombre!.isEmpty) {
          alert.showWarningDialog(
              context, "No se encontró el nombre del usuario");
          return;
        }
        await exportAndShareCSV(_productos, nombre!);
        break;
      case 3:
        _confirmarEliminarPallet(context);
        break;
    }
  }

  void _confirmarEliminarPallet(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text(
              '¿Estás seguro de que deseas eliminar este inventario? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo
              },
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo
                await dataBaseH.deleteReporteTim(widget.selectedInventario);
                Navigator.of(context)
                    .pop(true); // ← devuelve `true` para indicar que se eliminó
              },
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.verdeClaro,
          title: Text(
            'PERECIBLES - ${widget.selectedInventario.toString()}',
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
                                    labelText: 'SubDpto',
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
                          SizedBox(width: 10),
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
                                                          TextSpan(
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
                                                                '${producto.uRecibidas}${producto.uMedida == 'UN' ? '' : ' KG'}',
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
