import 'dart:io';

import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/utils/alerts.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:control_verde/utils/recepcion_producto_detalle.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/widgets/triState.dart';
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

class _ProductosReporteScreen extends State<ProductosReporteScreen>
    with WidgetsBindingObserver {
  List<Reporte> _productos = [];
  List<Reporte> _productosFiltrados = [];
  bool _verFaltantes = false;
  String? _descripcionFiltro;
  String? _eanFiltro;
  String? _subDeptFiltro;
  bool _filtrosVisbles = true;
  bool? _filtroMarcaSensible; // null = todos
  bool? _filtroIsContable;
  bool _isModalOpen = false; // Flag para rastrear si el modal de edición está abierto

  final ProductoService _productoService = ProductoService();

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
    'Limpieza': 'J0201',
    'Perfumería': 'J0202',
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
  final UserRepository _userRepo = UserRepository();
  String? nombre;

  final serviceDR = DetalleReporteService();
  final TextEditingController _controllerAddTim = TextEditingController();
  final alert = Alerts.instance;

  double? unidadesAddTim;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    WidgetsBinding.instance.addObserver(this);
    SocketService()
        .joinSala(widget.selectedTim.toString()); // Unir a la sala de recepción
    final socket = SocketService().socket;
    SocketService().onReconectado = _recargarVista;
    socket.on('producto-agregado', (data) {
      if (!mounted) return;
      final nuevoProducto = Reporte.fromJson(data);
      setState(() {
        _productos.add(nuevoProducto); // Agrega el producto a la lista
      });
      _actualizarFiltro();
    });

    socket.on('producto-actualizado', (data) {
      if (!mounted) return;
      final id = data['_id'];
      final nuevasURecibidas = double.tryParse(data['uRecibidas'].toString());
      final nuevoModificadoPor = data['modificadoPor'];

      if (nuevasURecibidas == null)
        return; // Manejo por si no es un número válido

      final index = _productos.indexWhere((p) => p.id == id);
      if (index != -1) {
        setState(() {
          _productos[index].uRecibidas = nuevasURecibidas;
          _productos[index].fastRegister = nuevasURecibidas > 0;
          _productos[index].modificadoPor = nuevoModificadoPor;
        });
      }
      _actualizarFiltro();
    });

    socket.on('detalle-bloqueado', (data) {
      if (!mounted) return;
      final id = data['id'];
      final editadoPor = data['editadoPor'];
      final index = _productos.indexWhere((p) => p.id == id);
      if (index != -1) {
        setState(() {
          _productos[index].isLocked = true;
          _productos[index].editadoPor = editadoPor;
        });
      }
      _actualizarFiltro();
    });

    socket.on('detalle-desbloqueado', (data) {
      if (!mounted) return;
      final id = data['id'];
      final index = _productos.indexWhere((p) => p.id == id);
      if (index != -1) {
        setState(() {
          _productos[index].isLocked = false;
          _productos[index].editadoPor = null;
        });
      }
      _actualizarFiltro();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarProductos();
      _actualizarFiltro();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketService().leaveSala();
    SocketService().onReconectado = null;
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final nombreUsuario = await _userRepo.getNombreUsuario();

    if (!mounted) return;

    setState(() {
      nombre = nombreUsuario;
    });
  }

  Future<void> _recargarVista() async {
    if (!mounted) return;
    await _cargarProductos(); // o lo que uses
    _actualizarFiltro();
  }

  Future<void> _cargarProductos() async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Cargando Productos');

    try {
      final productos =
          await serviceDR.obtenerProductosDeLaTim(context, widget.selectedTim);
      final info =
          await ReporteService().obtenerReporte(context, widget.selectedTim);

      if (!mounted) return;

      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
        reportesInfo = info;
      });
    } catch (error, stacktrace) {
      print("ERROR: $error");
      print("STACKTRACE: $stacktrace");

      if (mounted) {
        alert.showErrorDialog(context, 'Error al cargar productos\n$error');
      }
    } finally {
      if (mounted) Navigator.pop(dialogContext);
    }
  }

  // Future<void> _reCargaProductos() async {
  //   try {
  //     final productos =
  //         await serviceDR.obtenerProductosDeLaTim(widget.selectedTim);

  //     setState(() {
  //       _productos = productos;
  //       _subDeptOptions = productos
  //           .map((item) => item.subdpto) // Extraer los subdepartamentos
  //           .toSet() // Eliminar duplicados
  //           .toList(); // Conviertir de nuevo a lista
  //       _productosFiltrados = productos;
  //     });
  //   } catch (error) {
  //     print('Error al cargar productos: $error');
  //   }
  // }0

  String extraerCodigoCentral(String input) {
    String limpio = input.replaceFirst(RegExp(r'^0+'), '');
    if (limpio.length < 8) return limpio;
    int inicio = (limpio.length / 2).floor() - 4;
    return limpio.substring(inicio, inicio + 8);
  }

  void _actualizarFiltro() async {
    List<Reporte> base = _productos;

    // 1️⃣ Filtro faltantes
    if (_verFaltantes) {
      base = base.where((item) => item.uEnviadas > item.uRecibidas).toList();
    }

    List<Reporte> filtrados = base.where((item) {
      // 2️⃣ Filtro descripción
      final descripcionMatch = _descripcionFiltro == null ||
          _descripcionFiltro!.isEmpty ||
          item.descripcion
              .toLowerCase()
              .contains(_descripcionFiltro!.toLowerCase());

      // 3️⃣ Filtro subdepartamento
      final subDeptMatch = _subDeptFiltro == null ||
          _subDeptFiltro!.isEmpty ||
          item.subdpto.toLowerCase().contains(_subDeptFiltro!.toLowerCase());

      // 4️⃣ Filtro EAN / SKU
      bool eanMatch = true;
      if (_eanFiltro != null && _eanFiltro!.isNotEmpty) {
        if (_eanFiltro!.length == 8) {
          eanMatch =
              item.sku.contains(_eanFiltro!) || item.ean.contains(_eanFiltro!);
        } else {
          eanMatch = item.ean.contains(_eanFiltro!);
        }
      }

      // 5️⃣ 🔴 FILTRO MARCA SENSIBLE (CENTRAL)
      final marcaMatch = _filtroMarcaSensible == null ||
          item.marcaSensible == _filtroMarcaSensible;

      // 6️⃣ 🔵 FILTRO CONTABLE (TIENDA)
      final contableMatch =
          _filtroIsContable == null || item.isContable == _filtroIsContable;

      return descripcionMatch &&
          subDeptMatch &&
          eanMatch &&
          marcaMatch &&
          contableMatch;
    }).toList();

    filtrados.sort((a, b) => a.descripcion.compareTo(b.descripcion));

    // 7️⃣ Búsqueda profunda si no hay resultados
    if (filtrados.isEmpty && _eanFiltro != null && _eanFiltro!.isNotEmpty) {
      final posibleSku = extraerCodigoCentral(_eanFiltro!);

      final encontrados =
          base.where((item) => item.sku.contains(posibleSku)).toList();

      if (encontrados.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _productosFiltrados = encontrados;
        });
        return;
      }

      final service = ProductoService();
      final productoGeneral =
          await service.obtenerProductoPorCodigo(context, _eanFiltro!);

      if (!mounted) return;

      setState(() {
        _productoGenernal = productoGeneral;
        _productosFiltrados = [];
      });
      return;
    }

    // 8️⃣ Resultado final
    if (!mounted) return;
    setState(() {
      _productosFiltrados = filtrados;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      print('⏸️ App en background/interrumpida → pausar socket y cerrar modal');

      // Si el modal de edición está abierto, lo cerramos para liberar el bloqueo
      if (_isModalOpen) {
        print('🚪 Cerrando modal de edición por interrupción');
        Navigator.of(context).pop();
        _isModalOpen = false;
      }

      SocketService().pauseSocket();
    }

    if (state == AppLifecycleState.resumed) {
      print('▶️ App en foreground → reanudar socket');
      SocketService().resumeSocket();
    }
  }

  // List<Reporte> _aplicarFiltrosLocales() {
  //   List<Reporte> base = List.from(_productos);

  //   if (_verFaltantes) {
  //     base = base.where((p) => p.uEnviadas > p.uRecibidas).toList();
  //   }

  //   final filtrados = base.where((item) {
  //     final descripcionMatch = _descripcionFiltro == null ||
  //         _descripcionFiltro!.isEmpty ||
  //         item.descripcion
  //             .toLowerCase()
  //             .contains(_descripcionFiltro!.toLowerCase());

  //     final subDeptMatch = _subDeptFiltro == null ||
  //         _subDeptFiltro!.isEmpty ||
  //         item.subdpto == _subDeptFiltro;

  //     bool eanMatch = true;
  //     if (_eanFiltro != null && _eanFiltro!.isNotEmpty) {
  //       if (_eanFiltro!.length == 8) {
  //         eanMatch =
  //             item.sku.contains(_eanFiltro!) || item.ean.contains(_eanFiltro!);
  //       } else {
  //         eanMatch = item.ean.contains(_eanFiltro!);
  //       }
  //     }

  //     final marcaMatch = _filtroMarcaSensible == null ||
  //         item.marcaSensible == _filtroMarcaSensible;

  //     final contableMatch =
  //         _filtroIsContable == null || item.isContable == _filtroIsContable;

  //     return descripcionMatch &&
  //         subDeptMatch &&
  //         eanMatch &&
  //         marcaMatch &&
  //         contableMatch;
  //   }).toList();

  //   filtrados.sort((a, b) => a.descripcion.compareTo(b.descripcion));

  //   return filtrados;
  // }

  // Future<void> _buscarProductoGeneral() async {
  //   if (_eanFiltro == null || _eanFiltro!.isEmpty) return;

  //   final posibleSku = extraerCodigoCentral(_eanFiltro!);

  //   final encontrados =
  //       _productos.where((p) => p.sku.contains(posibleSku)).toList();

  //   if (encontrados.isNotEmpty) {
  //     if (!mounted) return;
  //     setState(() {
  //       _productosFiltrados = encontrados;
  //       _productoGenernal = null;
  //     });
  //     return;
  //   }

  //   try {
  //     final producto =
  //         await _productoService.obtenerProductoPorCodigo(context, _eanFiltro!);

  //     if (!mounted) return;

  //     setState(() {
  //       _productoGenernal = producto;
  //       _productosFiltrados = [];
  //     });
  //   } catch (_) {
  //     if (!mounted) return;
  //     setState(() {
  //       _productoGenernal = null;
  //       _productosFiltrados = [];
  //     });
  //   }
  // }

  // Future<void> _cambiarEstadoMasa() async {
  //   bool confirmar = await _mostrarConfirmacion();
  //   if (confirmar) {
  //     for (var producto in _productosFiltrados) {
  //       bool result;
  //       //if (activarTodo) {
  //       // Si activarTodo es true, activamos el switch
  //       result = await serviceDR.actualizarRecibidos(
  //           producto.id, producto.uEnviadas);
  //       //}

  //       // else {
  //       //   // Si activarTodo es false, desactivamos el switch
  //       //   result = await DatabaseHelper.instance
  //       //       .updateRecibidos(producto.id ?? 0, 0);
  //       // }

  //       // Si la actualización fue exitosa, actualizamos el estado del producto
  //       if (result) {
  //         setState(() {
  //           producto.fastRegister = true;
  //           //  producto.fastRegister = activarTodo;
  //           producto.uRecibidas = producto.uEnviadas;
  //         });
  //       } else {
  //         _showAlert('Error al actualizar los datos.');
  //         break;
  //       }
  //     }
  //   }
  // }

  // Future<bool> _mostrarConfirmacion() async {
  //   return (await showDialog<bool>(
  //         context: context,
  //         builder: (context) {
  //           return AlertDialog(
  //             title: Text('Confirmación'),
  //             content: Text(
  //                 '¿Estás seguro de que quieres  registras todos los productos?'),
  //             actions: <Widget>[
  //               TextButton(
  //                 child: Text('Cancelar'),
  //                 onPressed: () {
  //                   Navigator.of(context)
  //                       .pop(false); // Regresar false al cerrar el diálogo
  //                 },
  //               ),
  //               TextButton(
  //                 child: Text('Confirmar'),
  //                 onPressed: () {
  //                   Navigator.of(context)
  //                       .pop(true); // Regresar true al confirmar
  //                 },
  //               ),
  //             ],
  //           );
  //         },
  //       )) ??
  //       false;
  // }
  // Future<void> _toggleFastRegister(Reporte producto, bool value) async {
  //   if (nombre == null) return;

  //   final dialogContext = await loading.instance
  //       .showLoadingDialog(context, 'Actualizando producto');

  //   try {
  //     final result = await serviceDR.actualizarRecibidos(
  //       context,
  //       producto.id,
  //       value ? producto.uEnviadas : 0,
  //       nombre!,
  //       widget.selectedTim.toString(),
  //     );

  //     if (!result) {
  //       alert.showErrorDialog(context, 'Error al actualizar');
  //       return;
  //     }

  //     if (!mounted) return;

  //     setState(() {
  //       producto.fastRegister = value;
  //       producto.uRecibidas = value ? producto.uEnviadas : 0;
  //       producto.modificadoPor = value ? nombre! : '';
  //     });

  //     _actualizarFiltro();
  //   } finally {
  //     if (mounted) Navigator.pop(dialogContext);
  //   }
  // }

  Future<void> _insertarProductoSobrante(String sku) async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Agregando Producto');
    try {
      final reporteDR = DetalleReporte(
        id: '',
        tim: widget.selectedTim,
        olpn: 'SOBRANTE',
        sku: sku,
        uEnviadas: 0,
        uRecibidas: unidadesAddTim ?? 0,
        fechavencimiento: '',
        modificadoPor: nombre ?? '',
        observacion: 'SOBRANTE',
      );
      Reporte? result = await serviceDR.insertarDetalleReporte(
          context, reporteDR, widget.selectedTim.toString());
      if (result == null) {
        Navigator.pop(dialogContext);
        alert.showErrorDialog(
            context, "Hubo un error al agregar el producto como sobrante");
        return;
      }
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
    await loading.instance
        .showLoadingDialog(context, 'Bloqueando para edición...');

    try {
      final res = await serviceDR.cambiarEstadoEdicion(
        context,
        report.id,
        true,
        widget.selectedTim.toString(),
      );

      print('📥 [EDIT MODAL] Resultado bloqueo: ${res.success} - ${res.mensaje}');

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!res.success) {
        print('⚠️ [EDIT MODAL] Mostrando advertencia: ${res.mensaje}');
        alert.showWarningDialog(context, res.mensaje);
        return;
      }

      print('✅ Bloqueo exitoso: mostrando modal');
      _isModalOpen = true;
      final Reporte? result = await showDialog<Reporte>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return ReportDetailsDialog(
            report: report,
            motivo: reportesInfo?.motivo ?? 'T',
            onSave: () {},
          );
        },
      );
      _isModalOpen = false;

      if (result != null) {
        final index = _productos.indexWhere((p) => p.id == result.id);
        if (index != -1) {
          setState(() {
            _productos[index] = result;
            _actualizarFiltro();
          });
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      alert.showErrorDialog(context, 'Error al intentar editar: $e');
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

                    alert.showSuccessDialog(
                        context, "Archivo exportado: $filePath");
                  } else {
                    alert.showWarningDialog(
                        context, "Ingrese los campos necesarios");
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
      TextCellValue('SubDpto'),
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('CasePack'),
      TextCellValue('Cajas\nEnviadas'),
      TextCellValue('Unidades\nEnviadas'),
      TextCellValue('Conteo\nReal'),
      TextCellValue('Fecha\nVencimiento'),
    ]);

    for (var report in reports) {
      sheet.appendRow([
        TextCellValue(report.subdpto),
        TextCellValue(report.sku),
        TextCellValue(report.descripcion),
        IntCellValue(report.casePack),
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
            icon: _verFaltantes
                ? Icon(Icons.visibility)
                : Icon(Icons.visibility_off),
            onPressed: () => {
              setState(() {
                _verFaltantes = !_verFaltantes;
              }),
              _actualizarFiltro(),
            },
          ),
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
                                        color: const Color.fromARGB(
                                            255, 66, 50, 48),
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
                        SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _codigoController,
                            keyboardType: TextInputType.number,
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
                    Row(
                      children: [
                        Expanded(
                          child: TriStateFilter(
                            label: 'Sensible Central',
                            value: _filtroMarcaSensible,
                            onChanged: (v) {
                              setState(() => _filtroMarcaSensible = v);
                              _actualizarFiltro();
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: TriStateFilter(
                            label: 'Contable Tienda',
                            value: _filtroIsContable,
                            onChanged: (v) {
                              setState(() => _filtroIsContable = v);
                              _actualizarFiltro();
                            },
                          ),
                        ),
                      ],
                    ),
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
                                              _productoGenernal = null;
                                            } else {
                                              alert.showErrorDialog(context,
                                                  "Ingrese un número válido de unidades");
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
                                final bool eanVacio = producto.ean == null ||
                                    producto.ean.trim().isEmpty;
                                return Card(
                                  elevation: 4,
                                  color: eanVacio
                                      ? Colors.yellow[200]
                                      : Colors.white,
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
                                                color: producto.isLocked
                                                    ? Colors.grey
                                                    : Colors.blue,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (producto.isLocked)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(right: 8.0),
                                            child: Icon(Icons.lock,
                                                color: Colors.red, size: 20),
                                          ),
                                        Switch(
                                            value: producto.fastRegister, //
                                            activeColor: AppColors.verdeClaro,
                                            onChanged: producto.isLocked
                                                ? null
                                                : (value) async {
                                                    await loading.instance
                                                        .showLoadingDialog(
                                                            context,
                                                            'Actualizando...');
                                                    try {
                                                      final serviceDR =
                                                          DetalleReporteService();
                                                      String salaId = widget
                                                          .selectedTim
                                                          .toString();

                                                      // 1. Intentar bloquear temporalmente
                                                      final resLock =
                                                          await serviceDR
                                                              .cambiarEstadoEdicion(
                                                                  context,
                                                                  producto.id,
                                                                  true,
                                                                  salaId);
                                                      if (!mounted) return;
                                                      print(
                                                          '📥 [SWITCH] Resultado bloqueo: ${resLock.success} - ${resLock.mensaje}');
                                                      if (!resLock.success) {
                                                        if (mounted)
                                                          Navigator.of(context,
                                                                  rootNavigator:
                                                                      true)
                                                              .pop();
                                                        print(
                                                            '⚠️ [SWITCH] Mostrando advertencia');
                                                        alert.showWarningDialog(
                                                            context,
                                                            resLock.mensaje);
                                                        return;
                                                      }

                                                      // 2. Actualizar las unidades
                                                      final resUpdate =
                                                          await serviceDR
                                                              .actualizarRecibidos(
                                                                  context,
                                                                  producto.id,
                                                                  value
                                                                      ? producto
                                                                          .uEnviadas
                                                                      : 0,
                                                                  nombre!,
                                                                  salaId);
                                                      if (!mounted) return;

                                                      // 3. Siempre intentar desbloquear al final
                                                      await serviceDR
                                                          .cambiarEstadoEdicion(
                                                              context,
                                                              producto.id,
                                                              false,
                                                              salaId);
                                                      if (!mounted) return;

                                                      if (resUpdate.success) {
                                                        setState(() {
                                                          producto.fastRegister =
                                                              value;
                                                          producto.modificadoPor =
                                                              value
                                                                  ? nombre!
                                                                  : '';
                                                          producto.uRecibidas =
                                                              value
                                                                  ? producto
                                                                      .uEnviadas
                                                                  : 0;
                                                        });
                                                      } else {
                                                        alert.showErrorDialog(
                                                            context,
                                                            resUpdate.mensaje);
                                                      }
                                                    } catch (e) {
                                                      alert.showErrorDialog(
                                                          context, "Error: $e");
                                                    } finally {
                                                      if (mounted)
                                                        Navigator.of(context,
                                                                rootNavigator:
                                                                    true)
                                                            .pop();
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
                                                        TextSpan(
                                                          text:
                                                              producto.uMedida ==
                                                                      'UN'
                                                                  ? 'Unidades: '
                                                                  : 'Peso: ',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${producto.uEnviadas}${producto.uMedida == 'UN' ? '' : ' KG'}',
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
                                                                  ? Colors.red
                                                                  : Colors
                                                                      .amber,
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
                                    onTap: producto.isLocked
                                        ? () {
                                            alert.showWarningDialog(context,
                                                "Este detalle está siendo editado por ${producto.editadoPor}");
                                          }
                                        : () {
                                            _showReportDetails(
                                                context, producto);
                                          },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Cajas: ${_productosFiltrados.fold(0.0, (p, e) => p + (e.uEnviadas / e.casePack)).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Productos: ${_productosFiltrados.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
