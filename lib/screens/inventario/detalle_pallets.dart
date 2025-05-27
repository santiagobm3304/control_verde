import 'dart:io';

import 'package:control_verde/controller/files/files_controller.dart';
import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/screens/producto/nuevoproducto_screen.dart';
import 'package:control_verde/utils/inventario_producto_detalle.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:excel/excel.dart'
    show Sheet, Excel, TextCellValue, IntCellValue, DoubleCellValue;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PalletDetalleScreen extends StatefulWidget {
  final int selectedPallet;

  const PalletDetalleScreen({Key? key, required this.selectedPallet})
      : super(key: key);

  @override
  _PalletDetalleScreen createState() => _PalletDetalleScreen();
}

class _PalletDetalleScreen extends State<PalletDetalleScreen> {
  List<Reporte> _productos = [];
  List<Reporte> _productosFiltrados = [];
  String? _descripcionFiltro;
  String? _eanFiltro;
  String? _olpnFiltro;
  bool _filtrosVisbles = true;
  bool activarTodo = false;

  Producto? _productoGenernal;

  List<ReporteTim> reportesInfo = [];

  // TextEditingController _dateDesdeController = TextEditingController();
  // TextEditingController _dateHastaController = TextEditingController();
  TextEditingController _codigoController = TextEditingController();
  TextEditingController _descController = TextEditingController();
  // DateTime? _selectedDesdeDate;
  // DateTime? _selectedHastaDate;

  final TextEditingController _controllerAddTim = TextEditingController();
  final TextEditingController _controllerAddCaja = TextEditingController();

  late double cajaAddOlpn = 0;
  List<int> olpnsUnicos = [];
  double? unidadesAddTim;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final productos =
          await DatabaseHelper.instance.getReportesByTim(widget.selectedPallet);
      final reporteInfo = await DatabaseHelper.instance
          .getReporteTimByTim(widget.selectedPallet);

      setState(() {
        _productos = productos;
        olpnsUnicos = _productos
            .map((producto) => int.tryParse(producto.olpn))
            .where((olpn) => olpn != null)
            .map((olpn) => olpn!)
            .toSet()
            .toList()
          ..sort();
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
          await DatabaseHelper.instance.getReportesByTim(widget.selectedPallet);

      setState(() {
        _productos = productos;
        olpnsUnicos = _productos
            .map((producto) => int.tryParse(producto.olpn))
            .where((olpn) => olpn != null)
            .map((olpn) => olpn!)
            .toSet()
            .toList();
        _productosFiltrados = productos;
      });
    } catch (error) {
      print('Error al cargar productos: $error');
    }
  }

  void _actualizarFiltro() async {
    if (_eanFiltro != null && _eanFiltro!.isNotEmpty) {
      final productoGenal =
          await DatabaseHelper.instance.getProductobyEan(_eanFiltro!);
      setState(() {
        _productosFiltrados = [];
        _productoGenernal = productoGenal;
      });

      return;
    }
    // Si no hay filtro por EAN/SKU, usar filtro local
    setState(() {
      _productosFiltrados = _productos.where((item) {
        final descripcionMatch = _descripcionFiltro == null ||
            item.descripcion
                .toLowerCase()
                .contains(_descripcionFiltro!.toLowerCase());

        final olpnMatch = _olpnFiltro == null ||
            item.olpn.toLowerCase().contains(_olpnFiltro!.toLowerCase());

        return descripcionMatch && olpnMatch;
      }).toList();

      _productosFiltrados
          .sort((a, b) => a.descripcion.compareTo(b.descripcion));
    });
  }

  void _increment() {
    setState(() {
      cajaAddOlpn++;
      _controllerAddCaja.text = formatDoubleSmart(cajaAddOlpn);
    });
  }

  void _decrement() {
    if (cajaAddOlpn > 0) {
      setState(() {
        cajaAddOlpn--;
        _controllerAddCaja.text = formatDoubleSmart(cajaAddOlpn);
      });
    }
  }

  void _updateCount(String value) {
    double? newValue = double.tryParse(value);
    if (newValue != null) {
      setState(() {
        cajaAddOlpn = newValue;
        print(cajaAddOlpn);
      });
    } else if (value.isEmpty) {
      setState(() {
        cajaAddOlpn = 0;
        _controllerAddCaja.text = formatDoubleSmart(cajaAddOlpn);
      });
    }
  }

  String formatDoubleSmart(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toString();
    }
  }

  Future<void> _insertarProductoSobrante(Producto productoSobrante) async {
    try {
      final reporte = Reporte(
        ean: productoSobrante.ean,
        olpn: cajaAddOlpn.toInt().toString(),
        tim: widget.selectedPallet,
        descripcion: productoSobrante.descripcion,
        subdpto: productoSobrante.subdpto,
        sku: productoSobrante.sku,
        casePack: productoSobrante.casePack,
        uMedida: productoSobrante.uMedida,
        precioVigente: productoSobrante.precioVigente,
        costoPromedio: productoSobrante.costoPromedio,
        uEnviadas: 0,
        cEnviadas: ((unidadesAddTim ?? 0) / productoSobrante.casePack),
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
        return ProductoDetalleDialog(
          report: report,
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
        await DatabaseHelper.instance.deleteReporteWithCaja(
            widget.selectedPallet, producto.ean, producto.olpn);
        await _reCargaProductos();

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

  void _showExportDialog(BuildContext context) async {
    final TextEditingController _textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exportar Pallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PALLET #${widget.selectedPallet}'),
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
    sheet.appendRow(
        [TextCellValue('Pallet: '), IntCellValue(reportesInfo.first.tim)]);
    sheet.appendRow([
      TextCellValue('Origen: '),
      TextCellValue(reportesInfo.first.localOrigen!)
    ]);
    sheet.appendRow([
      TextCellValue('Fecha Registro: '),
      TextCellValue(reportesInfo.first.fechaEnvio!)
    ]);

    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('#PALLET'),
      TextCellValue('#CAJA'),
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
        TextCellValue(report.olpn),
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

    String formattedDate =
        DateFormat('dd-MM-yy_HH-mm-ss').format(DateTime.now());

    String fileName = 'PALLET_${reportesInfo.first.tim}_$formattedDate.xlsx';

    try {
      final downloadDirectory = Directory('/storage/emulated/0/Download');
      final filePath = '${downloadDirectory.path}/$fileName';

      if (!await downloadDirectory.exists()) {
        await downloadDirectory.create(recursive: true);
      }
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.save()!);

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
          child: Text('Exportar Pallet'),
        ),
        PopupMenuItem(
          value: 2,
          child: Text('Importar Productos'),
        ),
        PopupMenuItem(
          value: 3,
          child: Text('Eliminar Pallet'),
        ),
      ],
    );

    switch (result) {
      case 1:
        _showExportDialog(context);
        break;
      case 2:
        final result = await FilesController.instance
            .handleFileSelection(context, 0, tim: widget.selectedPallet);
        if (result == true) {
          await _reCargaProductos();
          _actualizarFiltro();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hubo un error al importar los productos')),
          );
        }
        break;
      case 3:
        _confirmarEliminarPallet(context);
        break;
      default:
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
              '¿Estás seguro de que deseas eliminar este pallet? Esta acción no se puede deshacer.'),
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
                await DatabaseHelper.instance
                    .deleteReportes(widget.selectedPallet);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pallet #${widget.selectedPallet}',
            style: TextStyle(color: AppColors.white)),
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
                                TextEditingValue(text: _olpnFiltro ?? ''),
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return olpnsUnicos
                                    .map((olpn) => olpn.toString())
                                    .toList();
                              }
                              return olpnsUnicos
                                  .map((olpn) => olpn.toString())
                                  .where((option) {
                                return option.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    );
                              });
                            },
                            displayStringForOption: (option) => option,
                            onSelected: (selectedOption) {
                              setState(() {
                                _olpnFiltro =
                                    olpnsUnicos[int.parse(selectedOption)]
                                        .toString();
                              });
                              _actualizarFiltro();
                            },
                            fieldViewBuilder: (context, controller, focusNode,
                                onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: '#Cajas',
                                  suffixIcon: IconButton(
                                    icon: _olpnFiltro == null
                                        ? Icon(Icons.arrow_drop_down,
                                            color: Colors.amber)
                                        : Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      if (_olpnFiltro != null) {
                                        setState(() {
                                          controller.text = "";
                                          _olpnFiltro = null;
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
                                    _olpnFiltro = value;
                                  });
                                  _actualizarFiltro();
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                  ],
                )),
            Expanded(
              child: _productosFiltrados.isEmpty
                  ? SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Agregue productos al pallet',
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
                                      'Producto Encontrado:',
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
                                            controller: _controllerAddCaja,
                                            textAlign: TextAlign.center,
                                            onChanged: _updateCount,
                                            decoration: InputDecoration(
                                              labelText: '#Caja',
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.grey,
                                                    width: 1.5),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: AppColors.black,
                                                    width: 2.0),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 12),
                                            ),
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black),
                                          ),
                                        ),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: _increment,
                                              child: Icon(
                                                Icons.keyboard_arrow_up,
                                                size: 24,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _decrement,
                                              child: Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          width: 15,
                                        ),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _controllerAddTim,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Unidades',
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
                                            final cajaNumero =
                                                cajaAddOlpn.toInt();
                                            print(olpnsUnicos);
                                            print(cajaNumero);
                                            if ((unidadesAddTim != null &&
                                                    unidadesAddTim! > 0 &&
                                                    _productoGenernal !=
                                                        null) &&
                                                (cajaNumero != 0 &&
                                                    cajaNumero > 0 &&
                                                    _productoGenernal !=
                                                        null)) {
                                              if (olpnsUnicos
                                                  .contains(cajaNumero)) {
                                                AwesomeDialog(
                                                  context: context,
                                                  dialogType:
                                                      DialogType.warning,
                                                  headerAnimationLoop: false,
                                                  title: 'Caja ya registrada',
                                                  desc:
                                                      'El número de caja "$cajaNumero" ya ha sido registrado. ¿Deseas continuar de todos modos?',
                                                  btnCancelText: "No",
                                                  btnOkText: "Sí",
                                                  btnCancelOnPress: () {},
                                                  btnOkOnPress: () {
                                                    _insertarProductoSobrante(
                                                        _productoGenernal!);
                                                    _codigoController.clear();
                                                    _eanFiltro = null;
                                                    _controllerAddTim.clear();
                                                    unidadesAddTim = null;
                                                  },
                                                ).show();
                                              } else {
                                                // Si no existe, continuar directamente
                                                _insertarProductoSobrante(
                                                    _productoGenernal!);
                                                _codigoController.clear();
                                                _eanFiltro = null;
                                                _controllerAddTim.clear();
                                                unidadesAddTim = null;
                                              }
                                            } else {
                                              AwesomeDialog(
                                                context: context,
                                                dialogType: DialogType.error,
                                                headerAnimationLoop: false,
                                                title: 'Error',
                                                desc:
                                                    'Por favor, llena el campo #Caja y Unidades para continuar.',
                                                btnOkOnPress: () {},
                                              ).show();
                                            }
                                          },
                                          label: const Text(
                                            'Agregar',
                                            style: TextStyle(
                                                color: AppColors.white),
                                          ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppColors.verdeOs,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Se agregará automáticamente al Pallet.',
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
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final response = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AgregarProductoScreen(),
                                          ),
                                        );
                                        if (response &&
                                            response['guardado'] == true) {
                                          await _reCargaProductos();
                                          _actualizarFiltro();
                                        }
                                      },
                                      icon: Icon(Icons.add),
                                      label: Text('Nuevo producto'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
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
                                            producto.descripcion.trim(),
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold),
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
                                                          text: 'Caja # ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${int.parse(producto.olpn)}',
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
                                                          text: 'Cajas: ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.cEnviadas}',
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
                                                                  'Unidades: ',
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
                                                                  '${producto.uRecibidas.toString()}',
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
                                            ],
                                          ),
                                        ),
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
                                  color: Colors.green[700],
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'Sgte Caja: (${(olpnsUnicos.isNotEmpty ? (olpnsUnicos.reduce((a, b) => a > b ? a : b) + 1) : 1)})',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
}
