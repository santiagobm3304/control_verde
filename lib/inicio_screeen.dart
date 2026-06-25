import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/auth/login.dart';

import 'package:control_verde/screens/donaciones/donaciones_screen.dart';
import 'package:control_verde/screens/inventario/inventario.dart';
import 'package:control_verde/screens/recepcion/recepcion.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/services/socket_service.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/app_data.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/utils/session_helper.dart';
import 'package:control_verde/utils/unauthorized.dart';
import 'package:control_verde/widgets/cardInicio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({Key? key}) : super(key: key);

  @override
  _InicioScreenState createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final UserRepository _userRepo = UserRepository();
  String? rol;
  String? nombre;

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

                    loader.showLoadingDialog(context, 'Registrando reporte');

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

                      if (!creado) {
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true)
                              .pop(); // cerrar loading
                          Navigator.pop(context, []);
                        }
                        return;
                      }

                      final tims = await serviceR.buscarPorMotivo(context, motivo);

                      if (!context.mounted) return;
                      Navigator.of(context, rootNavigator: true)
                          .pop(); // cerrar loading
                      Navigator.pop(context, tims);
                    } on UnauthorizedException catch (e) {
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true)
                            .pop(); // cerrar loading
                        await SesionHelper.cerrarSesion(
                          context,
                          mensaje: e.message,
                        );
                      }
                    } catch (e) {
                      debugPrint('ERROR: $e');
                      if (context.mounted) {
                        Navigator.of(context, rootNavigator: true)
                            .pop(); // cerrar loading
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
    if (!context.mounted) return;
    Navigator.pop(dialogContext);
    if (tims.isEmpty) {
      final nuevosTims = await mostrarFormularioDonacion(context, motivo);
      final dialogContext =
          await loading.instance.showLoadingDialog(context, 'Creando Donación');
      if (nuevosTims.isNotEmpty) {
        Navigator.pop(dialogContext);

        final int firstTim = nuevosTims.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListScreen(selectedTim: firstTim),
          ),
        );
      } else {
        Navigator.pop(dialogContext);
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

  // Future<void> _existsTimByMotivo(
  //   BuildContext context, {
  //   required String motivo,
  // }) async {
  //   final serviceR = ReporteService();
  //   List<int> tims = await serviceR.buscarPorMotivo(motivo);

  //   if (tims.isEmpty) {
  //     final nuevosTims = await mostrarFormularioDonacion(context, motivo);

  //     if (nuevosTims.isNotEmpty) {
  //       final int firstTim = nuevosTims.first;
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => ProductListScreen(selectedTim: firstTim),
  //         ),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('❌ No se creó la donación')),
  //       );
  //     }
  //   } else {
  //     final int firstTim = tims.first;
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => ProductListScreen(selectedTim: firstTim),
  //       ),
  //     );
  //   }
  // }

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
    // Si aún no cargó el rol → no mostrar nada
    if (rol == null) return [];

    List<Widget> modules = [];

    // Recepción
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

    // Donaciones
    if (rol != 'plataforma' || rol == 'plataforma') {
      // Todos menos un rol especial
      modules.add(
        CustomGridCard(
          icon: Icon(Icons.handshake, size: 40, color: AppColors.verdeClaro),
          title: 'Donaciones',
          onTap: (context) => _existsTimByMotivo(context, motivo: 'D'),
        ),
      );
    }

    // Inventario
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

    return modules;
  }
}
