import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/auth/login.dart';

import 'package:control_verde/screens/donaciones/donaciones_screen.dart';
import 'package:control_verde/screens/inventario/inventario.dart';
import 'package:control_verde/screens/nsg/nsg_screen.dart';
import 'package:control_verde/screens/nsg/nsg_screen2.dart';
import 'package:control_verde/screens/recepcion/recepcion.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/services/detalle_reporte_service.dart';
import 'package:control_verde/services/socket_service.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/app_data.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/utils/session_helper.dart';
import 'package:control_verde/utils/unauthorized.dart';
import 'package:control_verde/widgets/cardInicio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class InicioScreen extends StatefulWidget {
  const InicioScreen({Key? key}) : super(key: key);

  @override
  _InicioScreenState createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final UserRepository _userRepo = UserRepository();
  String? rol;
  String? nombre;

  // Evita que un doble toque (o un toque mientras ya hay una carga en
  // curso) dispare dos flujos NSG en paralelo compitiendo por el mismo
  // diálogo/navegación.
  bool _abriendoNsg = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    SocketService().init(); // Aquí se inicializa el socket correctamente
  }

  Future<void> _loadUser() async {
    final user = await _userRepo.getUser();
    setState(() {
      rol = user?.rol; // Puede ser: plataforma, perecibles, admin, supervisor
    });
  }

  /// Cierra un diálogo/ruta de forma segura: evita el crash
  /// '_history.isNotEmpty' si ya no hay nada que hacer pop (por ejemplo,
  /// si el servicio ya cerró la sesión y vació el stack de navegación
  /// mientras ese diálogo seguía abierto).
  void _safePop(BuildContext ctx, [dynamic result]) {
    final navigator = Navigator.of(ctx, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop(result);
    }
  }

  Future<List<int>> mostrarFormularioDonacion(
      BuildContext context, String motivo) async {
    final serviceR = ReporteService();
    final _formKey = GlobalKey<FormState>();
    final nombre = await _userRepo.getNombreUsuario();

    TextEditingController fechaController = TextEditingController(
      text: DateFormat('dd/MM/yy').format(DateTime.now()),
    );

    TextEditingController timController = TextEditingController();
    TextEditingController destinoController =
        TextEditingController(text: 'Donación');
    TextEditingController localOrigenController =
        TextEditingController(text: 'Pacasmayo');

    final tims = await showDialog<List<int>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Crear Donación"),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fechaController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Fecha de Envío",
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        FocusScope.of(context).unfocus();

                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(), // 👈 evita fechas futuras
                        );

                        if (picked != null) {
                          fechaController.text =
                              DateFormat('dd/MM/yy').format(picked);
                        }
                      },
                      validator: (value) => value == null || value.isEmpty
                          ? "Seleccione una fecha"
                          : null,
                    ),
                    TextFormField(
                      controller: timController,
                      decoration: InputDecoration(labelText: "Código Donación"),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty
                          ? "Ingrese el Código de Donación"
                          : null,
                    ),
                    TextFormField(
                      controller: destinoController,
                      decoration: InputDecoration(labelText: "Destino"),
                      validator: (value) =>
                          value!.isEmpty ? "Ingrese el Destino" : null,
                    ),
                    TextFormField(
                      controller: localOrigenController,
                      decoration: InputDecoration(labelText: "Local de Origen"),
                      validator: (value) =>
                          value!.isEmpty ? "Ingrese el local de origen" : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final loader = loading.instance;

                    final loaderCtx =
                        await loader.showLoadingDialog(context, 'Registrando reporte');

                    try {
                      final reporteTim = ReporteTim(
                        fechaEnvio: fechaController.text,
                        placa: 'Donación',
                        tim: int.parse(timController.text),
                        localDestino: destinoController.text,
                        localOrigen: localOrigenController.text,
                        creadoPor: nombre,
                        motivo: motivo,
                      );

                      final creado =
                          await serviceR.crearReporte(context, reporteTim);

                      // 🔑 `crearReporte` puede haber cerrado la sesión
                      // internamente (403) y ya haber reseteado toda la
                      // navegación. Si eso pasó, `context` (el del diálogo
                      // del formulario) ya no está montado: salimos sin
                      // tocar nada más.
                      if (!context.mounted) return;

                      if (!creado) {
                        _safePop(loaderCtx); // cerrar loading
                        Navigator.pop(context, []);
                        return;
                      }

                      final tims =
                          await serviceR.buscarPorMotivo(context, motivo);

                      if (!context.mounted) return;
                      _safePop(loaderCtx); // cerrar loading
                      Navigator.pop(context, tims);
                    } on UnauthorizedException catch (e) {
                      if (context.mounted) {
                        _safePop(loaderCtx); // cerrar loading
                        await SesionHelper.cerrarSesion(
                          context,
                          mensaje: e.message,
                        );
                      }
                    } catch (e) {
                      debugPrint('ERROR: $e');
                      if (context.mounted) {
                        _safePop(loaderCtx); // cerrar loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Error al registrar el reporte')),
                        );
                      }
                    }
                  },
                  child: Text("Guardar"),
                ),
              ],
            );
          },
        ) ??
        [];

    return tims;
  }

  Future<void> _existsTimByMotivo(
    BuildContext context, {
    required String motivo,
  }) async {
    final dialogContext =
        await loading.instance.showLoadingDialog(context, 'Obteniendo TIMS');
    final serviceR = ReporteService();
    List<int> tims = await serviceR.buscarPorMotivo(context, motivo);

    // 🔑 Igual que arriba: si buscarPorMotivo cerró sesión internamente,
    // `context` ya no está montado.
    if (!context.mounted) return;
    _safePop(dialogContext);

    if (tims.isEmpty) {
      final nuevosTims = await mostrarFormularioDonacion(context, motivo);
      if (!context.mounted) return;

      final dialogContext2 =
          await loading.instance.showLoadingDialog(context, 'Creando Donación');
      if (nuevosTims.isNotEmpty) {
        _safePop(dialogContext2);

        final int firstTim = nuevosTims.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListScreen(selectedTim: firstTim),
          ),
        );
      } else {
        _safePop(dialogContext2);
      }
    } else {
      final int firstTim = tims.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductListScreen(selectedTim: firstTim),
        ),
      );
    }
  }

  Future<void> _abrirNSG(BuildContext context) async {
    if (_abriendoNsg) return;
    _abriendoNsg = true;

    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Consultando reportes NSG...');
    final serviceR = ReporteService();

    try {
      final List<ReporteTim> reportes =
          await serviceR.buscarPorMotivov2(context, 'NSG');

      // 🔑 Punto crítico: si el 403 ya cerró la sesión dentro del service,
      // `context` (el de InicioScreen) ya no está montado. Salimos ANTES
      // de tocar el diálogo, que ya no existe en el stack.
      if (!context.mounted) return;
      _safePop(dialogContext);

      if (reportes.isEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NsgScreen()),
        );
      } else {
        _mostrarSelectorNsg(context, reportes);
      }
    } catch (e) {
      if (context.mounted) {
        _safePop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al consultar NSG: $e')),
        );
      }
    } finally {
      _abriendoNsg = false;
    }
  }

  Future<void> _abrirNSGv2(BuildContext context) async {
    if (_abriendoNsg) return;
    _abriendoNsg = true;

    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Consultando reportes NSG...');
    final serviceR = ReporteService();

    try {
      final List<ReporteTim> reportes =
          await serviceR.buscarPorMotivov2(context, 'NSG');

      // 🔑 Mismo punto crítico que en _abrirNSG: si hubo 403, la sesión
      // ya se cerró y el stack de navegación ya se vació. No tocar el
      // diálogo si `context` ya no está montado.
      if (!context.mounted) return;
      _safePop(dialogContext);

      if (reportes.isEmpty) {
        final nuevoTim = await _mostrarFormularioCrearNsgV2(context);
        if (nuevoTim != null && context.mounted) {
          await _abrirScannerNsg(context, nuevoTim);
        }
      } else {
        _mostrarSelectorNsgv2(context, reportes);
      }
    } catch (e) {
      if (context.mounted) {
        _safePop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al consultar NSG: $e')),
        );
      }
    } finally {
      _abriendoNsg = false;
    }
  }

  /// Precarga los productos ya registrados en [tim] (para que el detector
  /// de duplicados del escáner 2.0 funcione desde el primer segundo) y
  /// abre NsgScannerScreen.
  Future<void> _abrirScannerNsg(BuildContext context, int tim) async {
    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Cargando productos del reporte...');

    final detalleService = DetalleReporteService();
    List<dynamic> productosPrevios = [];
    try {
      productosPrevios =
          await detalleService.obtenerProductosDeLaTim(context, tim);
    } catch (e) {
      debugPrint('No se pudieron precargar productos NSG: $e');
      // Continuamos igual: el escáner funciona, solo que sin detección
      // de duplicados de lo ya escaneado hasta ahora.
    }

    // 🔑 Por si obtenerProductosDeLaTim también maneja 403 internamente.
    if (!context.mounted) return;
    _safePop(dialogContext);

    final nombreUsuario = await _userRepo.getNombreUsuario();
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NsgScannerScreen(
          tim: tim,
          nombreUsuario: nombreUsuario,
          productosIniciales: productosPrevios.cast(),
        ),
      ),
    );
  }

  void _mostrarSelectorNsg(BuildContext context, List<ReporteTim> reportes) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.inventory_2, color: AppColors.verdeOs),
              SizedBox(width: 8),
              Text(
                'Reportes NSG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecciona un reporte existente para continuar o crea uno nuevo:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: reportes.length,
                    itemBuilder: (itemCtx, index) {
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
                            'Reporte N°: ${rep.tim} - ${rep.creadoPor}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NsgScreen(selectedTim: rep.tim),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
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
                    'Crear Nuevo Reporte NSG',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NsgScreen(),
                      ),
                    );
                  },
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
          ],
        );
      },
    );
  }

  void _mostrarSelectorNsgv2(BuildContext context, List<ReporteTim> reportes) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.qr_code_scanner, color: AppColors.verdeOs),
              SizedBox(width: 8),
              Text('Reportes NSG (Escaneo 2.0)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecciona un reporte para continuar escaneando:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: reportes.length,
                    itemBuilder: (itemCtx, index) {
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
                            'Reporte N°: ${rep.tim} - ${rep.creadoPor}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: () async {
                            Navigator.pop(dialogCtx);
                            // 👇 Usamos el `context` EXTERNO (de
                            // InicioScreen), no el de este itemBuilder,
                            // porque ese se desmonta apenas cerramos el
                            // diálogo.
                            await _abrirScannerNsg(context, rep.tim);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
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
                    'Crear Nuevo Reporte NSG',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final nuevoTim = await _mostrarFormularioCrearNsgV2(context);
                    if (nuevoTim != null && context.mounted) {
                      await _abrirScannerNsg(context, nuevoTim);
                    }
                  },
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
          ],
        );
      },
    );
  }

  /// Formulario compacto para crear un nuevo registro NSG (usado por el
  /// flujo 2.0).
  Future<int?> _mostrarFormularioCrearNsgV2(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final random = Random();
    final int timGenerado = 1000 + random.nextInt(9000);

    final fechaController = TextEditingController(
      text: DateFormat('dd/MM/yy').format(DateTime.now()),
    );
    final timController = TextEditingController(text: timGenerado.toString());
    final destinoController = TextEditingController(text: 'Inventario NSG');
    final origenController = TextEditingController(text: '352 Pacasmayo');
    final serviceR = ReporteService();
    final nombreUsuario = await _userRepo.getNombreUsuario();

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.add_chart, color: AppColors.verdeOs),
                  SizedBox(width: 8),
                  Text('Crear Registro NSG',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                            icon: const Icon(Icons.refresh, color: AppColors.verdeOs),
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
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOs,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final timValue = int.parse(timController.text);
                    final reporteTim = ReporteTim(
                      fechaEnvio: fechaController.text,
                      placa: 'Inventario NSG',
                      tim: timValue,
                      localDestino: destinoController.text,
                      localOrigen: origenController.text,
                      creadoPor: nombreUsuario ?? 'Usuario',
                      motivo: 'NSG',
                    );

                    final loaderCtx = await loading.instance
                        .showLoadingDialog(dialogContext, 'Creando reporte NSG...');

                    final creado =
                        await serviceR.crearReporte(dialogContext, reporteTim);

                    // 🔑 crearReporte también puede haber cerrado la
                    // sesión internamente (403).
                    if (!dialogContext.mounted) return;
                    _safePop(loaderCtx);

                    if (creado && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(timValue);
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    await _userRepo.logout();

    // Redirigir y evitar que regrese
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Módulos', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: _getModules(context),
              ),
            ),
          ),
          // ── Footer con datos de la app ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.verdeClaro.withOpacity(0.08),
            child: Text(
              'v${AppData.appVersion}  •  Compilado: ${AppData.appFechaCompilacion}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getModules(BuildContext context) {
    if (rol == null) return [];

    List<Widget> modules = [];

    if (rol != 'perecibles') {
      modules.add(
        CustomGridCard(
          icon: Icon(Icons.list_alt, size: 40, color: AppColors.verdeClaro),
          title: 'Recepción',
          onTap: (context) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RecepcionScreen()),
          ),
        ),
      );
    }

    if (rol != 'plataforma' || rol == 'plataforma') {
      modules.add(
        CustomGridCard(
          icon: Icon(Icons.handshake, size: 40, color: AppColors.verdeClaro),
          title: 'Donaciones',
          onTap: (context) => _existsTimByMotivo(context, motivo: 'D'),
        ),
      );
    }

    if (rol != 'plataforma' || rol == 'plataforma') {
      modules.add(
        CustomGridCard(
          icon: Icon(Icons.stacked_line_chart,
              size: 40, color: AppColors.verdeClaro),
          title: 'Inventario',
          onTap: (context) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => InventarioScreen()),
          ),
        ),
      );
    }

    modules.add(
      CustomGridCard(
        icon: Icon(Icons.qr_code_scanner,
            size: 40, color: AppColors.verdeClaro),
        title: 'NSG',
        onTap: (context) => _abrirNSG(context),
      ),
    );

    modules.add(
      CustomGridCard(
        icon: Icon(Icons.camera_alt, size: 40, color: AppColors.verdeClaro),
        title: 'NSG 2.0',
        onTap: (context) => _abrirNSGv2(context),
      ),
    );

    return modules;
  }
}