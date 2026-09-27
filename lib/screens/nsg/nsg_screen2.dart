import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/detalle_reporte_model.dart';
import 'package:control_verde/model/producto_model.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/model/reporte_model.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/productos_service.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/utils/session_helper.dart';
import 'package:control_verde/utils/unauthorized.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:excel/excel.dart'
    show Sheet, Excel, TextCellValue, IntCellValue;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Pantalla de escaneo NSG 2.0
///
/// - Cámara activa de forma continua (no se detiene tras cada lectura).
/// - Notificaciones tipo "toast" moderno que se apilan y se desvanecen solas.
/// - Botón inferior derecho para ir a la lista de productos escaneados.
/// - Ingreso manual de código por si el escáner falla.
/// - Desde la lista: exportar, cambiar de reporte o finalizar y crear nuevo.
class NsgScannerScreen extends StatefulWidget {
  final int tim;
  final String? nombreUsuario;

  /// Productos ya escaneados previamente en esta TIM (opcional).
  final List<Reporte> productosIniciales;

  const NsgScannerScreen({
    Key? key,
    required this.tim,
    this.nombreUsuario,
    this.productosIniciales = const [],
  }) : super(key: key);

  @override
  State<NsgScannerScreen> createState() => _NsgScannerScreenState();
}

enum _ToastType { success, warning, error }

class _ToastData {
  final String id;
  final String title;
  final String? subtitle;
  final _ToastType type;

  _ToastData({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
  });
}

/// Maneja los sonidos del escaneo NSG. Cada sonido usa su propio
/// [AudioPlayer] en modo `lowLatency` para poder sonar rápido y de forma
/// seguida (ej. beep de escaneo + sonido de éxito casi al mismo tiempo)
/// sin que se corten entre sí.
///
/// Usa los archivos en assets/audio/ (beep.mp3, check.mp3, alert.mp3,
/// error.mp3). Declara la carpeta en pubspec.yaml:
///
/// flutter:
///   assets:
///     - assets/audio/
class _SonidosNsg {
  static const _rutaBeep = 'audio/beep1.mp3';
  static const _rutaSuccess = 'audio/check.mp3';
  static const _rutaWarning = 'audio/alert.mp3';
  static const _rutaError = 'audio/error.mp3';

  final AudioPlayer _beepPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _successPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _warningPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _errorPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);

  /// Sonido corto al leer/aceptar un código (escaneo o ingreso manual).
  Future<void> beep() => _play(_beepPlayer, _rutaBeep);

  /// Producto agregado correctamente al registro NSG.
  Future<void> exito() => _play(_successPlayer, _rutaSuccess);

  /// Advertencia: producto ya escaneado/registrado.
  Future<void> advertencia() => _play(_warningPlayer, _rutaWarning);

  /// Error: producto no encontrado o falla al registrar.
  Future<void> error() => _play(_errorPlayer, _rutaError);

  Future<void> _play(AudioPlayer player, String assetPath) async {
    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('No se pudo reproducir sonido ($assetPath): $e');
    }
  }

  void dispose() {
    _beepPlayer.dispose();
    _successPlayer.dispose();
    _warningPlayer.dispose();
    _errorPlayer.dispose();
  }
}

class _NsgScannerScreenState extends State<NsgScannerScreen> {
  late final MobileScannerController _scannerController;
  final _SonidosNsg _sonidos = _SonidosNsg();

  final DetalleReporteService _serviceDetalle = DetalleReporteService();
  final ProductoService _serviceProducto = ProductoService();
  final ReporteService _serviceReporte = ReporteService();
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final List<Reporte> _productos = [];
  final List<_ToastData> _toasts = [];
  int _toastCounter = 0;

  ReporteTim? _reporteInfo;

  bool _mostrarLista = false;
  bool _procesando = false;
  bool _torchOn = false;

  String? _ultimoCodigo;
  DateTime? _ultimoEscaneo;

  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _productos.addAll(widget.productosIniciales);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    _sonidos.dispose();
    super.dispose();
  }

  // ===========================================================================
  // DETECCIÓN Y PROCESAMIENTO DE CÓDIGOS
  // ===========================================================================

  void _onDetect(BarcodeCapture capture) {
    if (_mostrarLista) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _procesarCodigo(rawValue.trim());
  }

  String _extraerCodigoCentral(String input) {
    String limpio = input.replaceFirst(RegExp(r'^0+'), '');
    if (limpio.length < 8) return limpio;
    int inicio = (limpio.length / 2).floor() - 4;
    return limpio.substring(inicio, inicio + 8);
  }

  Future<void> _procesarCodigo(String codigo) async {
    if (codigo.isEmpty || !mounted) return;

    final ahora = DateTime.now();
    if (_ultimoCodigo == codigo &&
        _ultimoEscaneo != null &&
        ahora.difference(_ultimoEscaneo!) < const Duration(seconds: 2)) {
      return;
    }
    if (_procesando) return;

    _ultimoCodigo = codigo;
    _ultimoEscaneo = ahora;
    _procesando = true;

    // Timbrado de lectura: suena en cuanto se acepta un código nuevo,
    // antes de saber si es duplicado, no encontrado o válido.
    unawaited(_sonidos.beep());

    try {
      final centralCode =
          codigo.length >= 8 ? _extraerCodigoCentral(codigo) : codigo;

      Reporte? existente;
      for (final p in _productos) {
        if (p.ean == codigo ||
            p.sku == codigo ||
            p.sku == centralCode ||
            p.ean == centralCode) {
          existente = p;
          break;
        }
      }

      if (existente != null) {
        HapticFeedback.mediumImpact();
        unawaited(_sonidos.advertencia());
        _mostrarToast(
          title: 'Ya registrado',
          subtitle: existente.descripcion.trim(),
          type: _ToastType.warning,
        );
        return;
      }

      Producto? productoBackend;
      try {
        productoBackend =
            await _serviceProducto.obtenerProductoPorCodigo(context, codigo);
        if (productoBackend == null && centralCode != codigo && mounted) {
          productoBackend = await _serviceProducto.obtenerProductoPorCodigo(
              context, centralCode);
        }
      } on UnauthorizedException catch (e) {
        if (mounted) {
          await SesionHelper.cerrarSesion(context, mensaje: e.message);
        }
        return;
      } catch (e) {
        debugPrint('Error consultando producto: $e');
      }

      if (!mounted) return;

      if (productoBackend == null) {
        HapticFeedback.heavyImpact();
        unawaited(_sonidos.error());
        _mostrarToast(
          title: 'Producto no encontrado',
          subtitle: 'Código: $codigo',
          type: _ToastType.error,
        );
        return;
      }

      await _insertarProducto(productoBackend);
    } finally {
      _procesando = false;
    }
  }

  Future<void> _insertarProducto(Producto producto) async {
    try {
      final detalle = DetalleReporte(
        id: '',
        tim: widget.tim,
        olpn: 'Piso de venta',
        sku: producto.sku,
        uEnviadas: 0,
        uRecibidas: 1,
        fechavencimiento: '',
        observacion: 'NSG',
        modificadoPor: widget.nombreUsuario ?? '',
      );

      final Reporte? resultado = await _serviceDetalle.insertarDetalleReporte(
        context,
        detalle,
        widget.tim.toString(),
      );

      if (!mounted) return;

      if (resultado == null) {
        unawaited(_sonidos.error());
        _mostrarToast(
          title: 'No se pudo agregar',
          subtitle: producto.descripcion.trim(),
          type: _ToastType.error,
        );
        return;
      }

      setState(() {
        final index = _productos.indexWhere((p) => p.sku == resultado.sku);
        if (index == -1) {
          _productos.add(resultado);
        } else {
          _productos[index] = resultado;
        }
      });

      await _databaseHelper.insertReport(resultado);
      if (!mounted) return;

      HapticFeedback.lightImpact();
      unawaited(_sonidos.exito());
      _mostrarToast(
        title: 'Producto agregado',
        subtitle: resultado.descripcion.trim(),
        type: _ToastType.success,
      );
    } on UnauthorizedException catch (e) {
      if (mounted) {
        await SesionHelper.cerrarSesion(context, mensaje: e.message);
      }
    } catch (e) {
      if (!mounted) return;
      unawaited(_sonidos.error());
      _mostrarToast(
        title: 'Error al registrar',
        subtitle: e.toString(),
        type: _ToastType.error,
      );
    }
  }

  // ===========================================================================
  // INGRESO MANUAL DE CÓDIGO
  // ===========================================================================

  void _abrirIngresoManual() {
    _manualController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.keyboard, color: AppColors.verdeOs),
                  SizedBox(width: 8),
                  Text(
                    'Digitar código',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Código EAN / SKU',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                onSubmitted: (value) {
                  Navigator.pop(sheetCtx);
                  _procesarCodigo(value.trim());
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOs,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Buscar y agregar',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    final valor = _manualController.text.trim();
                    Navigator.pop(sheetCtx);
                    if (valor.isNotEmpty) {
                      _procesarCodigo(valor);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TOASTS
  // ===========================================================================

  void _mostrarToast({
    required String title,
    String? subtitle,
    required _ToastType type,
  }) {
    if (!mounted) return;
    final id = 'toast_${_toastCounter++}';
    setState(() {
      _toasts.add(
          _ToastData(id: id, title: title, subtitle: subtitle, type: type));
      if (_toasts.length > 4) {
        _toasts.removeAt(0);
      }
    });
  }

  void _removerToast(String id) {
    if (!mounted) return;
    setState(() {
      _toasts.removeWhere((t) => t.id == id);
    });
  }

  // ===========================================================================
  // NAVEGACIÓN INTERNA (SCANNER <-> LISTA)
  // ===========================================================================

  void _irALista() {
    setState(() => _mostrarLista = true);
    _scannerController.stop();
  }

  void _volverAEscanear() {
    setState(() => _mostrarLista = false);
    _scannerController.start();
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  /// Cierra un diálogo/ruta de forma segura: evita el crash
  /// '_history.isNotEmpty' si ya no hay nada que hacer pop (por ejemplo,
  /// si dos flujos con sesión vencida se disparan casi al mismo tiempo).
  void _safePop(BuildContext ctx, [dynamic result]) {
    final navigator = Navigator.of(ctx, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop(result);
    }
  }

  Future<void> _eliminarDeLista(Reporte producto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Eliminar "${producto.descripcion.trim()}" del registro NSG?',
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

    if (confirm != true || !mounted) return;

    try {
      final eliminado = await _serviceDetalle.eliminarDetalleReporte(
        context,
        producto.id,
        widget.tim.toString(),
      );

      if (eliminado && mounted) {
        setState(() {
          _productos.removeWhere((p) => p.id == producto.id);
        });
        await _databaseHelper.deleteReporte(producto.sku, widget.tim);
      }
    } on UnauthorizedException catch (e) {
      if (mounted) {
        await SesionHelper.cerrarSesion(context, mensaje: e.message);
      }
    } catch (e) {
      debugPrint('Error al eliminar producto: $e');
    }
  }

  // ===========================================================================
  // MENÚ: EXPORTAR / CAMBIAR REPORTE / FINALIZAR Y CREAR NUEVO
  // ===========================================================================

  void _showOptionsMenu() async {
    final result = await showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(300, 80, 16, 0),
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
              Icon(Icons.swap_horiz, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cambiar Reporte NSG'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 4,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.teal),
              SizedBox(width: 8),
              Text('Finalizar Reporte'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 5,
          child: Row(
            children: [
              Icon(Icons.playlist_add_check, color: AppColors.verdeOs),
              SizedBox(width: 8),
              Text('Finalizar y Crear Nuevo'),
            ],
          ),
        ),
      ],
    );

    if (result == null || !mounted) return;

    switch (result) {
      case 1:
        await _exportarExcel();
        break;
      case 2:
        await _exportarCSV();
        break;
      case 3:
        await _cambiarReporte();
        break;
      case 4:
        await _finalizarTim(crearNuevoDespues: false);
        break;
      case 5:
        await _finalizarTim(crearNuevoDespues: true);
        break;
    }
  }

  Future<ReporteTim?> _asegurarReporteInfo() async {
    if (_reporteInfo != null) return _reporteInfo;
    try {
      _reporteInfo = await _serviceReporte.obtenerReporte(context, widget.tim);
    } on UnauthorizedException catch (e) {
      if (mounted) {
        await SesionHelper.cerrarSesion(context, mensaje: e.message);
      }
    } catch (e) {
      debugPrint('No se pudo obtener info del reporte: $e');
    }
    return _reporteInfo;
  }

  Future<void> _exportarCSV() async {
    await _asegurarReporteInfo();
    if (!mounted) return;

    try {
      final buffer = StringBuffer();
      buffer.writeln('Preventores:;${widget.nombreUsuario ?? ''}');
      buffer.writeln('Inventario NSG:;${widget.tim}');
      buffer.writeln(
          'Origen:;${_reporteInfo?.localOrigen ?? '352 Pacasmayo'}');
      buffer.writeln('Fecha Registro:;${_reporteInfo?.fechaEnvio ?? ''}');
      buffer.writeln('');
      buffer.writeln('DIVISION;EAN;SKU;DESCRIPCION;OK;OBSV');

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
      final fileName = 'NSG_${widget.tim}_$formattedDate.csv';
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(
          [0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'text/csv')],
        subject: 'Reporte NSG - ${widget.tim}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar CSV: $e')),
        );
      }
    }
  }

  Future<void> _exportarExcel() async {
    await _asegurarReporteInfo();
    if (!mounted) return;

    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    sheet.appendRow([
      TextCellValue('Preventores:'),
      TextCellValue(widget.nombreUsuario ?? '')
    ]);
    sheet.appendRow(
        [TextCellValue('Inventario NSG:'), IntCellValue(widget.tim)]);
    sheet.appendRow([
      TextCellValue('Origen:'),
      TextCellValue(_reporteInfo?.localOrigen ?? '352 Pacasmayo')
    ]);
    sheet.appendRow([
      TextCellValue('Destino:'),
      TextCellValue(_reporteInfo?.localDestino ?? 'NSG')
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
        TextCellValue(report.descripcion),
        TextCellValue(report.uRecibidas > 0 ? 'OK' : 'NO'),
        TextCellValue(report.observacion),
      ]);
    }

    final formattedDate =
        DateFormat('dd-MM-yy_HH-mm-ss').format(DateTime.now());
    final fileName = 'NSG_${widget.tim}_$formattedDate.xlsx';

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        final directory = Directory('/storage/emulated/0/Download');
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(excel.save()!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exportado a Descargas: $fileName')),
          );
        }
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.save()!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportado en documentos: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar Excel: $e')),
        );
      }
    }
  }

  Future<void> _cambiarReporte() async {
    if (!mounted) return;
    final loaderCtx = await loading.instance
        .showLoadingDialog(context, 'Consultando registros...');

    List<int> tims = [];
    try {
      tims = await _serviceReporte.buscarPorMotivo(context, 'NSG');
    } on UnauthorizedException catch (e) {
      if (mounted) {
        _safePop(loaderCtx);
        await SesionHelper.cerrarSesion(context, mensaje: e.message);
      }
      return;
    } catch (e) {
      if (mounted) {
        _safePop(loaderCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al consultar registros: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    _safePop(loaderCtx);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cambiar Reporte NSG'),
        content: SizedBox(
          width: double.maxFinite,
          child: tims.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay otros registros NSG disponibles.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: tims.length,
                  itemBuilder: (itemCtx, index) {
                    final t = tims[index];
                    final isActual = t == widget.tim;
                    return ListTile(
                      leading: Icon(Icons.receipt_long,
                          color: isActual ? AppColors.verdeOs : Colors.grey),
                      title: Text(
                        'Reporte NSG: $t',
                        style: TextStyle(
                            fontWeight: isActual
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                      trailing: isActual
                          ? const Chip(
                              label: Text('Actual',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              backgroundColor: AppColors.verdeOs,
                            )
                          : null,
                      onTap: isActual
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _cargarProductosYReemplazar(t);
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarProductosYReemplazar(int tim) async {
    if (!mounted) return;
    final loaderCtx = await loading.instance
        .showLoadingDialog(context, 'Cargando reporte...');

    List<Reporte> productos = [];
    try {
      productos = await _serviceDetalle.obtenerProductosDeLaTim(context, tim);
    } on UnauthorizedException catch (e) {
      if (mounted) {
        _safePop(loaderCtx);
        await SesionHelper.cerrarSesion(context, mensaje: e.message);
      }
      return;
    } catch (e) {
      debugPrint('Error cargando productos del reporte $tim: $e');
    }

    if (!mounted) return;
    _safePop(loaderCtx);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NsgScannerScreen(
          tim: tim,
          nombreUsuario: widget.nombreUsuario,
          productosIniciales: productos,
        ),
      ),
    );
  }

  /// Finaliza el reporte NSG actual usando el mismo servicio que ya usa
  /// NsgScreen (`eliminarTim`). Pese al nombre, ese servicio NO borra los
  /// productos ni el histórico: solo le pone fecha de expiración al
  /// registro NSG en el backend para marcarlo como completado.
  ///
  /// Si [crearNuevoDespues] es true, al finalizar exitosamente abre el
  /// formulario para crear un nuevo registro y reemplaza esta pantalla por
  /// el escáner del nuevo TIM. Si es false, simplemente cierra la pantalla.
  Future<void> _finalizarTim({required bool crearNuevoDespues}) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline,
                color: AppColors.verdeOs, size: 28),
            SizedBox(width: 8),
            Text('Finalizar Reporte NSG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Has registrado ${_productos.length} productos en el reporte ${widget.tim}.\n\n'
          'Al finalizar, el reporte ya no podrás seguir agregando productos a '
          'este registro.'
          '${crearNuevoDespues ? '\n\n¿Deseas finalizarlo y crear uno nuevo para continuar escaneando?' : '\n\n¿Deseas finalizarlo ahora?'}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verdeOs,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              crearNuevoDespues ? 'Finalizar y Crear Nuevo' : 'Finalizar Reporte',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final loaderCtx = await loading.instance
        .showLoadingDialog(context, 'Finalizando reporte...');

    bool finalizado = false;
    try {
      finalizado = await _serviceReporte.eliminarTim(context, widget.tim);
    } on UnauthorizedException catch (e) {
      if (mounted) {
        _safePop(loaderCtx);
        await SesionHelper.cerrarSesion(context, mensaje: e.message);
      }
      return;
    } catch (e) {
      if (mounted) {
        _safePop(loaderCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar el reporte: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    _safePop(loaderCtx);
    if (!mounted) return;

    if (!finalizado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo finalizar el reporte.')),
      );
      return;
    }

    // Igual que NsgScreen: al finalizar en el backend, se limpia también
    // la copia local de ese registro (ya no está activo para seguir
    // trabajándolo desde este dispositivo).
    await _databaseHelper.deleteReporteTim(widget.tim);
    if (!mounted) return;

    if (!crearNuevoDespues) {
      Navigator.of(context).pop(_productos);
      return;
    }

    final nuevoTim = await _mostrarFormularioCrearNsg(context);
    if (nuevoTim != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NsgScannerScreen(
            tim: nuevoTim,
            nombreUsuario: widget.nombreUsuario,
            productosIniciales: const [],
          ),
        ),
      );
    } else if (mounted) {
      // Se finalizó el reporte pero canceló crear uno nuevo: no queda
      // ningún TIM activo en esta pantalla, así que cerramos.
      Navigator.of(context).pop(_productos);
    }
  }

  /// Formulario compacto para crear un nuevo registro NSG sin depender de
  /// InicioScreen, para que esta pantalla sea autosuficiente.
  Future<int?> _mostrarFormularioCrearNsg(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final random = Random();
    final int timGenerado = 1000 + random.nextInt(9000);

    final fechaController = TextEditingController(
      text: DateFormat('dd/MM/yy').format(DateTime.now()),
    );
    final timController = TextEditingController(text: timGenerado.toString());

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.add_chart, color: AppColors.verdeOs),
                  SizedBox(width: 8),
                  Text('Crear Registro NSG',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                            onPressed: () {
                              setModalState(() {
                                timController.text =
                                    (1000 + random.nextInt(9000)).toString();
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
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final timValue = int.parse(timController.text);
                    final reporteTim = ReporteTim(
                      fechaEnvio: fechaController.text,
                      placa: 'Inventario NSG',
                      tim: timValue,
                      localDestino: 'Inventario NSG',
                      localOrigen: '352 Pacasmayo',
                      creadoPor: widget.nombreUsuario ?? 'Usuario',
                      motivo: 'NSG',
                    );

                    final loaderCtx = await loading.instance
                        .showLoadingDialog(
                            dialogContext, 'Creando reporte NSG...');
                    try {
                      final creado = await _serviceReporte.crearReporte(
                          dialogContext, reporteTim);
                      if (dialogContext.mounted) {
                        _safePop(loaderCtx);
                      }
                      if (creado) {
                        await _databaseHelper.insertReporteTim(reporteTim);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(timValue);
                        }
                      }
                    } on UnauthorizedException catch (e) {
                      if (dialogContext.mounted) {
                        _safePop(loaderCtx);
                        await SesionHelper.cerrarSesion(dialogContext,
                            mensaje: e.message);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        _safePop(loaderCtx);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content: Text('Error al crear el reporte: $e')),
                        );
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
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_productos);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final entrandoDesdeElDerecho =
                child.key == const ValueKey('lista');
            final offsetAnim = Tween<Offset>(
              begin: entrandoDesdeElDerecho
                  ? const Offset(1, 0)
                  : const Offset(-1, 0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offsetAnim,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _mostrarLista
              ? _buildListaView(key: const ValueKey('lista'))
              : _buildScannerView(key: const ValueKey('scanner')),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- SCANNER
  Widget _buildScannerView({required Key key}) {
    return Stack(
      key: key,
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),

        // Degradado superior para legibilidad de la barra.
        // OJO: envuelto en Positioned — sin esto, al ser hijo directo de un
        // Stack con fit:expand, se estira a toda la pantalla.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // Marco guía de escaneo (decorativo)
        IgnorePointer(
          child: Center(
            child: Container(
              width: 250,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.verdeOs, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        // Barra superior — FIX: ahora sí envuelta en Positioned(top:0,...),
        // por eso antes aparecía centrada en medio de la pantalla en vez de
        // arriba.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(_productos),
                  ),
                  const Expanded(
                    child: Text(
                      'Escaneo NSG',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    tooltip: 'Digitar código',
                    onPressed: _abrirIngresoManual,
                  ),
                  IconButton(
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    tooltip: 'Linterna',
                    onPressed: _toggleTorch,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Pila de mensajes tipo toast
        Positioned(
          left: 12,
          right: 12,
          bottom: 110,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _toasts
                .map((t) => _ToastCard(
                      key: ValueKey(t.id),
                      data: t,
                      onExpired: () => _removerToast(t.id),
                    ))
                .toList(),
          ),
        ),

        // Botón inferior derecho: ir a la lista
        Positioned(
          right: 16,
          bottom: 24,
          child: _ListaFab(
            count: _productos.length,
            onTap: _irALista,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ LISTA
  Widget _buildListaView({required Key key}) {
    return Container(
      key: key,
      color: AppColors.background,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: _volverAEscanear,
                      ),
                      Expanded(
                        child: Text(
                          'Productos escaneados (${_productos.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Más opciones',
                        onPressed: _showOptionsMenu,
                      ),
                    ],
                  ),
                ),
                Text(
                  'Reporte NSG: ${widget.tim}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _productos.isEmpty
                      ? Center(
                          child: Text(
                            'Aún no has escaneado productos',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
                          itemCount: _productos.length,
                          itemBuilder: (context, index) {
                            final producto = _productos[index];
                            return Card(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(
                                  producto.descripcion.trim(),
                                  style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  'SKU: ${producto.sku}   SubDpto: ${producto.subdpto}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _eliminarDeLista(producto),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            // Botón inferior derecho: volver a escanear
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.verdeOs,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text('Escanear de nuevo',
                    style: TextStyle(color: Colors.white)),
                onPressed: _volverAEscanear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET: FAB "Ir a la lista" con contador
// ============================================================================

class _ListaFab extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ListaFab({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton.extended(
          backgroundColor: AppColors.verdeOs,
          icon: const Icon(Icons.list_alt, color: Colors.white),
          label:
              const Text('Ver lista', style: TextStyle(color: Colors.white)),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// WIDGET: Tarjeta de notificación (toast moderno, se desvanece solo)
// ============================================================================

class _ToastCard extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onExpired;

  const _ToastCard({Key? key, required this.data, required this.onExpired})
      : super(key: key);

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;

  static const _visibleDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(_fade);
    _controller.forward();

    _timer = Timer(_visibleDuration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onExpired();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _bgColor() {
    switch (widget.data.type) {
      case _ToastType.success:
        return const Color(0xFF1F8A4C);
      case _ToastType.warning:
        return const Color(0xFFB8860B);
      case _ToastType.error:
        return const Color(0xFFC62828);
    }
  }

  IconData _icon() {
    switch (widget.data.type) {
      case _ToastType.success:
        return Icons.check_circle;
      case _ToastType.warning:
        return Icons.warning_amber_rounded;
      case _ToastType.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bgColor().withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(_icon(), color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.data.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.data.subtitle != null &&
                          widget.data.subtitle!.isNotEmpty)
                        Text(
                          widget.data.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}