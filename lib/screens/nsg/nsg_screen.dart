import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/services/socket_service.dart';
import 'package:control_verde/utils/alerts.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:excel/excel.dart'
    show Sheet, Excel, TextCellValue, IntCellValue, DoubleCellValue;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class NsgScreen extends StatefulWidget {
  final int? selectedTim;

  const NsgScreen({Key? key, this.selectedTim}) : super(key: key);

  @override
  _NsgScreenState createState() => _NsgScreenState();
}

class _NsgScreenState extends State<NsgScreen> {
  int? _currentTim;
  ReporteTim? _reporteInfo;
  List<Reporte> _productos = [];
  List<Reporte> _productosFiltrados = [];

  String? _descripcionFiltro;
  String? _eanFiltro;
  String? _subDeptFiltro;
  bool _filtrosVisibles = true;
  String? _nombreUsuario;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  final Map<String, String> _subDeptMap = {
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
    'Electro': 'J11',
  };

  final ReporteService _serviceReporte = ReporteService();
  final DetalleReporteService _serviceDetalle = DetalleReporteService();
  final ProductoService _serviceProducto = ProductoService();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;
  final UserRepository _userRepo = UserRepository();
  final Alerts _alerts = Alerts.instance;

  @override
  void initState() {
    super.initState();
    _currentTim = widget.selectedTim;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _cargarUsuario();
      if (!mounted) return;
      if (_currentTim != null) {
        await _iniciarConTim(_currentTim!);
      } else {
        await _buscarOInicializarReporte();
      }
    });
  }

  @override
  void dispose() {
    SocketService().leaveSala();
    _descController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // CONFIGURACIÓN DE USUARIO Y TIM
  // ===========================================================================

  Future<void> _cargarUsuario() async {
    final user = await _userRepo.getUser();
    if (!mounted) return;
    setState(() {
      _nombreUsuario = user?.nombre ?? '';
    });
  }

  int _generarTimAleatorio() {
    final random = Random();
    return 1000 + random.nextInt(9000);
  }

  Future<void> _buscarOInicializarReporte() async {
    if (!mounted) return;
    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Consultando registros NSG...');

    try {
      final List<ReporteTim> reportes =
          await _serviceReporte.buscarPorMotivov2(context, 'NSG');
      if (mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }

      if (!mounted) return;

      if (reportes.isEmpty) {
        // No hay registros NSG, mostrar formulario para crear nuevo
        final nuevoTim = await _mostrarFormularioCrearNsg(context);
        if (!mounted) return;
        if (nuevoTim != null) {
          await _iniciarConTim(nuevoTim);
        } else {
          Navigator.of(context).pop();
        }
      } else if (reportes.length == 1) {
        // Solo hay un registro, cargarlo directamente
        await _iniciarConTim(reportes.first.tim);
      } else {
        // Hay múltiples registros, mostrar selector para que el usuario elija
        if (!mounted) return;
        await _mostrarSeleccionTimInicio(reportes);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        _alerts.showErrorDialog(
            context, 'Error al consultar registros NSG: $e');
      }
    }
  }

  Future<void> _iniciarConTim(int tim) async {
    if (!mounted) return;
    setState(() {
      _currentTim = tim;
    });

    _configurarSockets(tim);
    await _cargarProductos(tim);
  }

  /// Muestra un selector de TIM al iniciar la pantalla (cuando hay varios TIMs).
  /// A diferencia de [_mostrarSeleccionTim], este método es async y espera
  /// a que el usuario elija antes de continuar.
  Future<void> _mostrarSeleccionTimInicio(List<ReporteTim> reportes) async {
    if (!mounted) return;
    final timElegido = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.inventory_2, color: AppColors.verdeOs),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Registros NSG',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecciona un registro para continuar o crea uno nuevo:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: reportes.length,
                    itemBuilder: (context, index) {
                      final rep = reportes[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.qr_code,
                              color: AppColors.verdeOs),
                          title: Text(
                            'Reporte: ${rep.tim} - ${rep.creadoPor}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: () => Navigator.pop(ctx, rep.tim),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOs,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon:
                      const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: const Text(
                    'Crear Nuevo Registro NSG',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => Navigator.pop(ctx, -1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (timElegido == null) {
      // Canceló → salir de la pantalla
      Navigator.of(context).pop();
    } else if (timElegido == -1) {
      // Quiere crear uno nuevo
      final nuevoTim = await _mostrarFormularioCrearNsg(context);
      if (!mounted) return;
      if (nuevoTim != null) {
        await _iniciarConTim(nuevoTim);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      // TIM seleccionado
      await _iniciarConTim(timElegido);
    }
  }

  void _configurarSockets(int tim) {
    SocketService().leaveSala();
    SocketService().joinSala(tim.toString());

    final socket = SocketService().socket;
    SocketService().onReconectado = () async {
      debugPrint('♻️ Reconexión detectada en sala NSG $tim');
      await _cargarProductos(tim);
    };

    socket.off('producto-agregado');
    socket.off('producto-eliminado');
    socket.off('producto-actualizado');

    socket.on('producto-agregado', (data) {
      if (!mounted) return;
      try {
        final nuevo = Reporte.fromJson(data);
        final index = _productos.indexWhere((p) => p.sku == nuevo.sku);
        setState(() {
          if (index == -1) {
            _productos.add(nuevo);
          } else {
            _productos[index] = nuevo;
          }
        });
        _actualizarFiltro();
      } catch (e) {
        debugPrint('Error procesando socket producto-agregado: $e');
      }
    });

    socket.on('producto-eliminado', (data) {
      if (!mounted) return;
      final id = data.toString();
      setState(() {
        _productos.removeWhere((p) => p.id == id);
      });
      _actualizarFiltro();
    });

    socket.on('producto-actualizado', (data) {
      if (!mounted) return;
      try {
        final id = data['_id'];
        final nuevasURecibidas =
            double.tryParse(data['uRecibidas']?.toString() ?? '');
        final index = _productos.indexWhere((p) => p.id == id);
        if (index != -1 && nuevasURecibidas != null) {
          setState(() {
            _productos[index].uRecibidas = nuevasURecibidas;
            _productos[index].fastRegister = nuevasURecibidas > 0;
          });
          _actualizarFiltro();
        }
      } catch (e) {
        debugPrint('Error procesando socket producto-actualizado: $e');
      }
    });
  }

  Future<void> _cargarProductos(int tim) async {
    if (!mounted) return;
    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Cargando productos NSG...');
    try {
      final productosBackend =
          await _serviceDetalle.obtenerProductosDeLaTim(context, tim);
      if (!mounted) return;
      final info = await _serviceReporte.obtenerReporte(context, tim);

      if (!mounted) return;
      setState(() {
        _productos = productosBackend;
        _reporteInfo = info;
        _productosFiltrados = List.from(productosBackend);
      });
      Navigator.of(dialogContext, rootNavigator: true).pop();
    } catch (e) {
      if (mounted) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
        _alerts.showErrorDialog(context, 'Error al cargar productos: $e');
      }
    }
  }

  // ===========================================================================
  // FORMULARIO CREAR REPORTE NSG
  // ===========================================================================

  Future<int?> _mostrarFormularioCrearNsg(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final int timGenerado = _generarTimAleatorio();

    final fechaController = TextEditingController(
      text: DateFormat('dd/MM/yy').format(DateTime.now()),
    );
    final timController = TextEditingController(text: timGenerado.toString());
    final placaController = TextEditingController(text: 'Inventario NSG');
    final destinoController = TextEditingController(text: 'Inventario NSG');
    final origenController = TextEditingController(text: '352 Pacasmayo');

    return await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.add_chart, color: AppColors.verdeOs),
                  SizedBox(width: 8),
                  Text(
                    'Crear Registro NSG',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: fechaController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha del Reporte',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            fechaController.text =
                                DateFormat('dd/MM/yy').format(picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: timController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Código Reporte NSG',
                          prefixIcon: const Icon(Icons.tag),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh,
                                color: AppColors.verdeOs),
                            tooltip: 'Generar nuevo código',
                            onPressed: () {
                              setModalState(() {
                                timController.text =
                                    _generarTimAleatorio().toString();
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOs,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final loaderDialog = await loading.instance
                        .showLoadingDialog(
                            dialogContext, 'Creando reporte NSG...');

                    try {
                      final timValue = int.parse(timController.text);
                      final reporteTim = ReporteTim(
                        fechaEnvio: fechaController.text,
                        placa: placaController.text,
                        tim: timValue,
                        localDestino: destinoController.text,
                        localOrigen: origenController.text,
                        creadoPor: _nombreUsuario ?? 'Usuario',
                        motivo: 'NSG',
                      );

                      final creado = await _serviceReporte.crearReporte(
                          dialogContext, reporteTim);

                      if (dialogContext.mounted) {
                        Navigator.of(loaderDialog, rootNavigator: true).pop();
                      }

                      if (creado) {
                        await _databaseHelper.insertReporteTim(reporteTim);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(timValue);
                        }
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        Navigator.of(loaderDialog, rootNavigator: true).pop();
                        _alerts.showErrorDialog(
                            dialogContext, 'Error al crear el reporte: $e');
                      }
                    }
                  },
                  child: const Text('Guardar',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // FILTRADO Y BÚSQUEDA
  // ===========================================================================

  String _extraerCodigoCentral(String input) {
    String limpio = input.replaceFirst(RegExp(r'^0+'), '');
    if (limpio.length < 8) return limpio;
    int inicio = (limpio.length / 2).floor() - 4;
    return limpio.substring(inicio, inicio + 8);
  }

  void _actualizarFiltro() {
    setState(() {
      _productosFiltrados = _productos.where((item) {
        final descripcionMatch = _descripcionFiltro == null ||
            _descripcionFiltro!.isEmpty ||
            item.descripcion
                .toLowerCase()
                .contains(_descripcionFiltro!.toLowerCase());

        final subDeptMatch = _subDeptFiltro == null ||
            _subDeptFiltro!.isEmpty ||
            item.subdpto.toLowerCase().contains(_subDeptFiltro!.toLowerCase());

        bool eanMatch = true;
        if (_eanFiltro != null && _eanFiltro!.isNotEmpty) {
          final query = _eanFiltro!.trim();
          if (query.length == 8) {
            eanMatch = item.sku.contains(query) || item.ean.contains(query);
          } else {
            eanMatch = item.ean.contains(query) || item.sku.contains(query);
          }
        }

        return descripcionMatch && eanMatch && subDeptMatch;
      }).toList();

      _productosFiltrados
          .sort((a, b) => a.descripcion.compareTo(b.descripcion));
    });
  }

  // ===========================================================================
  // PROCESAMIENTO DE CÓDIGO (ESCANEO O INGRESO MANUAL)
  // ===========================================================================

  Future<void> _procesarCodigo(String rawCode) async {
    final codigo = rawCode.trim();
    if (codigo.isEmpty) return;

    if (_currentTim == null) {
      if (mounted) {
        _alerts.showWarningDialog(
          context,
          'No hay ningún registro NSG seleccionado.',
        );
      }
      return;
    }

    // 1️⃣ Buscar primero en la lista cargada de productos en pantalla
    Reporte? productoExistente;
    final centralCode =
        codigo.length >= 8 ? _extraerCodigoCentral(codigo) : codigo;

    for (var p in _productos) {
      if (p.ean == codigo ||
          p.sku == codigo ||
          p.sku == centralCode ||
          p.ean == centralCode) {
        productoExistente = p;
        break;
      }
    }

    if (productoExistente != null) {
      // ⚠️ El producto ya fue escaneado en esta TIM
      _mostrarModalProductoYaEscaneado(productoExistente);
      setState(() {
        _eanFiltro = codigo;
        _codigoController.text = codigo;
      });
      _actualizarFiltro();
      return;
    }

    // 2️⃣ Si NO está en la lista cargada, consultar al backend
    if (!mounted) return;
    final loader = await loading.instance
        .showLoadingDialog(context, 'Consultando producto en el backend...');

    Producto? productoBackend;
    try {
      productoBackend =
          await _serviceProducto.obtenerProductoPorCodigo(context, codigo);

      if (productoBackend == null && centralCode != codigo && mounted) {
        productoBackend = await _serviceProducto.obtenerProductoPorCodigo(
            context, centralCode);
      }
    } catch (e) {
      debugPrint('Error al consultar producto en backend: $e');
    } finally {
      if (mounted) {
        Navigator.of(loader, rootNavigator: true).pop();
      }
    }

    if (productoBackend == null) {
      if (mounted) {
        _alerts.showWarningDialog(
          context,
          'Producto no encontrado en el sistema con el código: $codigo',
        );
      }
      return;
    }

    // 3️⃣ Preguntar al usuario si desea agregarlo al registro NSG
    if (mounted) {
      // _mostrarModalConfirmarAgregar(productoBackend);
      _insertarProductoNsg(productoBackend);
    }
  }

  // ===========================================================================
  // MODAL: PRODUCTO YA ESCANEADO
  // ===========================================================================

  void _mostrarModalProductoYaEscaneado(Reporte producto) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El producto ya fue escaneado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Text(
                    '⚠️ Este producto ya está registrado en la lista NSG. '
                    'Compara la descripción para verificar si el código de barras se leyó correctamente.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  producto.descripcion.trim(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 10),
                _buildInfoRow('SKU:', producto.sku),
                _buildInfoRow('EAN:', producto.ean),
                _buildInfoRow('SubDpto:', producto.subdpto),
                _buildInfoRow('Cantidad Registrada:',
                    '${producto.uRecibidas} ${producto.uMedida}'),
                _buildInfoRow('Ubicación:', producto.olpn),
                _buildInfoRow('Observación:', producto.observacion),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.edit, size: 16, color: Colors.white),
              label: const Text('Ver / Editar Detalle',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _mostrarDialogoDetalle(producto);
              },
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // MODAL: CONFIRMAR AGREGAR PRODUCTO
  // ===========================================================================

  // void _mostrarModalConfirmarAgregar(Producto producto) {
  //   showDialog(
  //     context: context,
  //     builder: (dialogCtx) {
  //       return AlertDialog(
  //         shape:
  //             RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         title: Row(
  //           children: const [
  //             Icon(Icons.add_shopping_cart, color: AppColors.verdeOs, size: 26),
  //             SizedBox(width: 8),
  //             Expanded(
  //               child: Text(
  //                 '¿Desea agregar este producto?',
  //                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
  //               ),
  //             ),
  //           ],
  //         ),
  //         content: SingleChildScrollView(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Text(
  //                 producto.descripcion.trim(),
  //                 style: const TextStyle(
  //                   fontSize: 15,
  //                   fontWeight: FontWeight.bold,
  //                   color: Colors.blueAccent,
  //                 ),
  //               ),
  //               const SizedBox(height: 12),
  //               _buildInfoRow('SKU:', producto.sku),
  //               _buildInfoRow('EAN:', producto.ean),
  //               _buildInfoRow('SubDpto:', producto.subdpto),
  //               _buildInfoRow('Proveedor:', producto.proveedor),
  //               _buildInfoRow('Case Pack:', '${producto.casePack}'),
  //               _buildInfoRow('Costo Promedio:',
  //                   'S/. ${producto.costoPromedio.toStringAsFixed(2)}'),
  //               const Divider(height: 20),
  //               Container(
  //                 padding: const EdgeInsets.all(10),
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey.shade100,
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Column(
  //                   children: [
  //                     _buildInfoRow('Ubicación:', 'Piso de venta'),
  //                     _buildInfoRow('Observación:', ''),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(dialogCtx),
  //             child: const Text('Cancelar',
  //                 style: TextStyle(color: Colors.redAccent)),
  //           ),
  //           ElevatedButton(
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: AppColors.verdeOs,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //             ),
  //             onPressed: () async {
  //               Navigator.pop(dialogCtx);
  //               await _insertarProductoNsg(producto);
  //             },
  //             child: const Text('Agregar Producto',
  //                 style: TextStyle(color: Colors.white)),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<void> _insertarProductoNsg(Producto producto) async {
    if (!mounted) return;
    final loader = await loading.instance
        .showLoadingDialog(context, 'Agregando producto al NSG...');

    try {
      final detalle = DetalleReporte(
        id: '',
        tim: _currentTim,
        olpn: 'Piso de venta',
        sku: producto.sku,
        uEnviadas: 0,
        uRecibidas: 1, // 1 unidad para exposición de venta
        fechavencimiento: '',
        observacion: 'NSG',
        modificadoPor: _nombreUsuario ?? '',
      );

      final Reporte? resultado = await _serviceDetalle.insertarDetalleReporte(
        context,
        detalle,
        _currentTim.toString(),
      );

      if (mounted) {
        Navigator.of(loader, rootNavigator: true).pop();
      }

      if (resultado != null) {
        setState(() {
          final index = _productos.indexWhere((p) => p.sku == resultado.sku);
          if (index == -1) {
            _productos.add(resultado);
          } else {
            _productos[index] = resultado;
          }
          _codigoController.clear();
          _eanFiltro = null;
        });
        _actualizarFiltro();

        await _databaseHelper.insertReport(resultado);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${producto.descripcion} agregado correctamente'),
              backgroundColor: AppColors.verdeOs,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(loader, rootNavigator: true).pop();
        _alerts.showErrorDialog(context, 'Error al registrar el producto: $e');
      }
    }
  }

  // ===========================================================================
  // DIÁLOGO DETALLE / EDICIÓN DE PRODUCTO
  // ===========================================================================

  void _mostrarDialogoDetalle(Reporte reporte) {
    final cantController = TextEditingController(
      text: reporte.uRecibidas % 1 == 0
          ? reporte.uRecibidas.toInt().toString()
          : reporte.uRecibidas.toString(),
    );
    final obsController = TextEditingController(text: reporte.observacion);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            reporte.descripcion.trim(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('SKU:', reporte.sku),
                _buildInfoRow('EAN:', reporte.ean),
                _buildInfoRow('SubDpto:', reporte.subdpto),
                _buildInfoRow('Ubicación (OLPN):', reporte.olpn),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cantController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad Recibida',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: obsController,
                  decoration: const InputDecoration(
                    labelText: 'Observación',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_alt),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeOs,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final double nuevaCantidad =
                    double.tryParse(cantController.text) ?? reporte.uRecibidas;

                final reporteActualizado = Reporte(
                  id: reporte.id,
                  tim: reporte.tim,
                  olpn: reporte.olpn,
                  subdpto: reporte.subdpto,
                  ean: reporte.ean,
                  sku: reporte.sku,
                  descripcion: reporte.descripcion,
                  casePack: reporte.casePack,
                  uMedida: reporte.uMedida,
                  precioVigente: reporte.precioVigente,
                  costoPromedio: reporte.costoPromedio,
                  uEnviadas: reporte.uEnviadas,
                  uRecibidas: nuevaCantidad,
                  fechavencimiento: reporte.fechavencimiento,
                  observacion: obsController.text,
                  modificadoPor: _nombreUsuario,
                );

                final loader = await loading.instance
                    .showLoadingDialog(dialogCtx, 'Actualizando producto...');

                final status = await _serviceDetalle.actualizarDatosDetalle(
                  dialogCtx,
                  reporteActualizado,
                  _currentTim.toString(),
                );

                if (dialogCtx.mounted) {
                  Navigator.of(loader, rootNavigator: true).pop();
                }

                if (status > 0) {
                  setState(() {
                    final index =
                        _productos.indexWhere((p) => p.id == reporte.id);
                    if (index != -1) {
                      _productos[index] = reporteActualizado;
                    }
                  });
                  _actualizarFiltro();
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                }
              },
              child:
                  const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ELIMINACIÓN DE PRODUCTO
  // ===========================================================================

  void _eliminarProducto(Reporte producto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de eliminar el producto "${producto.descripcion.trim()}" del registro NSG?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && _currentTim != null && mounted) {
      final loader = await loading.instance
          .showLoadingDialog(context, 'Eliminando producto...');

      final eliminado = await _serviceDetalle.eliminarDetalleReporte(
        context,
        producto.id,
        _currentTim.toString(),
      );

      if (mounted) {
        Navigator.of(loader, rootNavigator: true).pop();
      }

      if (eliminado) {
        setState(() {
          _productos.removeWhere((p) => p.id == producto.id);
        });
        _actualizarFiltro();

        await _databaseHelper.deleteReporte(producto.sku, _currentTim!);

        if (mounted) {
          _alerts.showSuccessDialog(
              context, 'El producto ha sido eliminado del registro.');
        }
      }
    }
  }

  // ===========================================================================
  // EXPORTAR Y COMPARTIR
  // ===========================================================================

  Future<void> _exportAndShareCSV() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Preventores:;${_nombreUsuario ?? ''}');
      buffer.writeln('Inventario NSG:;${_currentTim ?? ''}');
      buffer.writeln('Origen:;${_reporteInfo?.localOrigen ?? '352 Pacasmayo'}');
      buffer.writeln('Fecha Registro:;${_reporteInfo?.fechaEnvio ?? ''}');
      buffer.writeln('');

      buffer.writeln(
        'DIVISION;EAN;SKU;DESCRIPCION;OK;OBSV',
      );

      for (var report in _productos) {
        final descripcion = report.descripcion.replaceAll(';', ',');
        buffer.writeln(
          '${report.subdpto};${report.ean};${report.sku};$descripcion;'
          '${report.uRecibidas > 0 ? 'OK' : 'NO'};${report.observacion}',
        );
      }

      final dir = await getTemporaryDirectory();
      final formattedDate =
          DateFormat('dd-MM-yy_HH-mm-ss').format(DateTime.now());
      final fileName = 'NSG_${_currentTim}_$formattedDate.csv';
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file
          .writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'text/csv')],
        subject: 'Reporte NSG - $_currentTim',
      );
    } catch (e) {
      if (mounted) {
        _alerts.showErrorDialog(context, 'Error al exportar CSV: $e');
      }
    }
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    sheet.appendRow(
        [TextCellValue('Preventores:'), TextCellValue(_nombreUsuario ?? '')]);
    sheet.appendRow(
        [TextCellValue('Inventario NSG:'), IntCellValue(_currentTim ?? 0)]);
    sheet.appendRow([
      TextCellValue('Origen:'),
      TextCellValue(_reporteInfo?.localOrigen ?? '352 Pacasmayo')
    ]);
    sheet.appendRow([
      TextCellValue('Destino:'),
      TextCellValue(_reporteInfo?.localDestino ?? 'Inventario')
    ]);
    sheet.appendRow([
      TextCellValue('Fecha Registro:'),
      TextCellValue(_reporteInfo?.fechaEnvio ?? '')
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('DIVISION'),
      TextCellValue('EAN'),
      TextCellValue('SKU'),
      TextCellValue('Descripción'),
      TextCellValue('OK'),
      TextCellValue('Observación'),
    ]);

    for (var report in _productos) {
      sheet.appendRow([
        TextCellValue(report.subdpto),
        TextCellValue(report.ean),
        TextCellValue(report.sku),
        TextCellValue(report.uRecibidas > 0 ? "OK" : "NO"),
        TextCellValue(report.observacion),
      ]);
    }

    final formattedDate =
        DateFormat('dd-MM-yy_HH-mm-ss').format(DateTime.now());
    final fileName = 'NSG_${_currentTim}_$formattedDate.xlsx';

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        final directory = Directory('/storage/emulated/0/Download');
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(excel.save()!);
        if (mounted) {
          _alerts.showSuccessDialog(
            context,
            'Archivo exportado correctamente a Descargas:\n$fileName',
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.save()!);
      if (mounted) {
        _alerts.showSuccessDialog(
          context,
          'Archivo exportado en documentos:\n$fileName',
        );
      }
    } catch (e) {
      if (mounted) {
        _alerts.showErrorDialog(context, 'Error al exportar Excel: $e');
      }
    }
  }

  void _showOptionsMenu(BuildContext context) async {
    final result = await showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(300, 92, 0, 0),
      items: const [
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.file_download, color: Colors.blue),
              SizedBox(width: 8),
              Text('Exportar a Excel'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            children: [
              Icon(Icons.share, color: Colors.green),
              SizedBox(width: 8),
              Text('Compartir como CSV'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(Icons.add_circle, color: AppColors.verdeOs),
              SizedBox(width: 8),
              Text('Crear Nuevo Reporte NSG'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 4,
          child: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cambiar Reporte NSG'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 5,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.teal),
              SizedBox(width: 8),
              Text('Finalizar Reporte NSG'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 6,
          child: Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar Registro NSG'),
            ],
          ),
        ),
      ],
    );

    if (result == null) return;

    switch (result) {
      case 1:
        await _exportToExcel();
        break;
      case 2:
        await _exportAndShareCSV();
        break;
      case 3:
        final nuevoTim = await _mostrarFormularioCrearNsg(context);
        if (nuevoTim != null) {
          await _iniciarConTim(nuevoTim);
        }
        break;
      case 4:
        _mostrarSeleccionTim();
        break;
      case 5:
        // _finalizarReporte();
        _confirmarEliminarYCrearNuevo();
        break;
      case 6:
        _confirmarEliminarTim();
        break;
    }
  }

  void _confirmarEliminarYCrearNuevo() {
    if (_currentTim == null) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text(
            '¿Estás seguro de que deseas eliminar este registro NSG ($_currentTim)? '
            'Se eliminará y podrás crear un nuevo registro a continuación. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                final timAEliminar = _currentTim!;

                final loader = await loading.instance
                    .showLoadingDialog(context, 'Eliminando registro...');

                final eliminado =
                    await _serviceReporte.eliminarTim(context, timAEliminar);

                if (mounted) {
                  Navigator.of(loader, rootNavigator: true).pop();
                }

                if (eliminado) {
                  await _databaseHelper.deleteReporteTim(timAEliminar);

                  if (!mounted) return;

                  // En vez de cerrar la pantalla, abrimos el flujo de creación
                  final nuevoTim = await _mostrarFormularioCrearNsg(context);
                  if (nuevoTim != null) {
                    await _iniciarConTim(nuevoTim);
                  } else if (mounted) {
                    // Si el usuario cancela la creación del nuevo, cerramos la pantalla
                    Navigator.of(context).pop();
                  }
                }
              },
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _finalizarReporte() {
    if (_currentTim == null) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline,
                  color: AppColors.verdeOs, size: 28),
              SizedBox(width: 8),
              Text(
                'Finalizar Reporte NSG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Has completado el registro de ${_productos.length} productos en el reporte: $_currentTim.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                '¿Qué deseas realizar a continuación?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Volver al escaneo',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.share, size: 16, color: Colors.white),
              label: const Text('Exportar / Compartir',
                  style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _exportAndShareCSV();
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.verdeOs,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Finalizar y Crear Nuevo',
                  style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final nuevoTim = await _mostrarFormularioCrearNsg(context);
                if (nuevoTim != null) {
                  await _iniciarConTim(nuevoTim);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarSeleccionTim() async {
    if (!mounted) return;
    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Consultando registros...');
    final tims = await _serviceReporte.buscarPorMotivo(context, 'NSG');
    if (mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Registros NSG'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tims.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No hay otros registros NSG disponibles.'),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tims.length,
                      itemBuilder: (context, index) {
                        final tim = tims[index];
                        final isSelected = tim == _currentTim;
                        return ListTile(
                          leading: Icon(
                            Icons.receipt_long,
                            color: isSelected ? AppColors.verdeOs : Colors.grey,
                          ),
                          title: Text('REPORTE NSG: $tim',
                              style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          trailing: isSelected
                              ? const Chip(
                                  label: Text('Activo',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                  backgroundColor: AppColors.verdeOs,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _iniciarConTim(tim);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOs,
                    minimumSize: const Size(double.infinity, 42),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Crear Nuevo Registro',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final nuevoTim = await _mostrarFormularioCrearNsg(context);
                    if (nuevoTim != null) {
                      await _iniciarConTim(nuevoTim);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmarEliminarTim() {
    if (_currentTim == null) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text(
            '¿Estás seguro de que deseas eliminar este registro NSG ($_currentTim)? '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final loader = await loading.instance
                    .showLoadingDialog(context, 'Eliminando registro...');

                final eliminado =
                    await _serviceReporte.eliminarTim(context, _currentTim!);

                if (mounted) {
                  Navigator.of(loader, rootNavigator: true).pop();
                }

                if (eliminado) {
                  await _databaseHelper.deleteReporteTim(_currentTim!);
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // WIDGET HELPERS
  // ===========================================================================

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD PRINCIPAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.verdeClaro,
        title: Text(
          'NSG - ${_currentTim ?? 'Cargando...'}',
          style: const TextStyle(
              color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _filtrosVisibles ? Icons.filter_list_off : Icons.filter_list,
              color: AppColors.white,
            ),
            tooltip: _filtrosVisibles ? 'Ocultar filtros' : 'Mostrar filtros',
            onPressed: () {
              setState(() {
                _filtrosVisibles = !_filtrosVisibles;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            tooltip: 'Más opciones',
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILTROS
            Visibility(
              visible: _filtrosVisibles,
              child: Column(
                children: [
                  // Filtro Descripción
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Descripción',
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 10.0),
                      suffixIcon: _descripcionFiltro == null ||
                              _descripcionFiltro!.isEmpty
                          ? const Icon(Icons.description, color: Colors.amber)
                          : IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _descController.clear();
                                  _descripcionFiltro = null;
                                });
                                _actualizarFiltro();
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
                  const SizedBox(height: 10),

                  // Filtros SubDpto y SKU / EAN
                  Row(
                    children: [
                      // SubDpto Autocomplete
                      Expanded(
                        child: Autocomplete<String>(
                          initialValue:
                              TextEditingValue(text: _subDeptFiltro ?? ''),
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return _subDeptMap.keys.toList();
                            }
                            return _subDeptMap.keys.where((option) {
                              return option.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase());
                            }).toList();
                          },
                          displayStringForOption: (option) => option,
                          onSelected: (selectedOption) {
                            setState(() {
                              _subDeptFiltro = _subDeptMap[selectedOption]!;
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
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 10.0),
                                suffixIcon: _subDeptFiltro == null
                                    ? const Icon(Icons.arrow_drop_down,
                                        color: Colors.amber)
                                    : IconButton(
                                        icon: const Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () {
                                          setState(() {
                                            controller.clear();
                                            _subDeptFiltro = null;
                                          });
                                          _actualizarFiltro();
                                        },
                                      ),
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
                      const SizedBox(width: 10),

                      // Sku / Ean con Escáner
                      Expanded(
                        child: TextFormField(
                          controller: _codigoController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: 'Sku / Ean',
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 10.0),
                            suffixIcon: _eanFiltro == null ||
                                    _eanFiltro!.isEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.qr_code_scanner,
                                        color: Colors.amber),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const BarcodeScannerSimple(),
                                        ),
                                      );

                                      if (result != null &&
                                          result.toString().isNotEmpty) {
                                        final codeScanned =
                                            result.toString().trim();
                                        _codigoController.text = codeScanned;
                                        await _procesarCodigo(codeScanned);
                                      }
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _codigoController.clear();
                                        _eanFiltro = null;
                                      });
                                      _actualizarFiltro();
                                    },
                                  ),
                          ),
                          onFieldSubmitted: (value) async {
                            await _procesarCodigo(value);
                          },
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
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // LISTADO DE PRODUCTOS O ESTADO VACÍO
            Expanded(
              child: _productosFiltrados.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron productos en el registro NSG',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Escanee o ingrese un código de barras para verificar y agregar productos.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.verdeOs,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.qr_code_scanner,
                                  color: Colors.white),
                              label: const Text('Escanear Producto',
                                  style: TextStyle(color: Colors.white)),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const BarcodeScannerSimple(),
                                  ),
                                );

                                if (result != null &&
                                    result.toString().isNotEmpty) {
                                  final codeScanned = result.toString().trim();
                                  _codigoController.text = codeScanned;
                                  await _procesarCodigo(codeScanned);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) {
                        final producto = _productosFiltrados[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 6.0),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    producto.descripcion.trim(),
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red, size: 22),
                                  onPressed: () => _eliminarProducto(producto),
                                  tooltip: 'Eliminar producto',
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'SKU: ${producto.sku}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                    Text(
                                      'SubDpto: ${producto.subdpto}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black87),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Ubicación: ${producto.olpn}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black87),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.verdeOs.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppColors.verdeOs),
                                      ),
                                      child: Text(
                                        '${producto.uRecibidas > 0 ? "Ok" : "Vacío"}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.verdeOs,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (producto.observacion.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Obs: ${producto.observacion}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _mostrarDialogoDetalle(producto),
                          ),
                        );
                      },
                    ),
            ),

            // CONTADOR INFERIOR DE PRODUCTOS
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              margin: const EdgeInsets.only(top: 8.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Productos: ${_productosFiltrados.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Reporte NSG: ${_currentTim ?? '-'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
