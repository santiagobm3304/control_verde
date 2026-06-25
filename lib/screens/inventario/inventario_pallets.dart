import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/inventario/detalle_pallets.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/screens/qr/mobile_scanner.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/widgets/cardInicio.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PalletsInventarioScreen extends StatefulWidget {
  final String motivo;

  const PalletsInventarioScreen({Key? key, required this.motivo})
      : super(key: key);

  @override
  _PalletsInventarioScreen createState() => _PalletsInventarioScreen();
}

class _PalletsInventarioScreen extends State<PalletsInventarioScreen> {
  List<int> reportesInfo = [];
  List<int> _reportesFiltrados = [];
  TextEditingController _filtroController = TextEditingController();
  UserRepository _userRepo = UserRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarTims();
    });
  }

  Future<void> _cargarTims() async {
    try {
      final dialogContext = await loading.instance
          .showLoadingDialog(context, 'Cargando Reportes');
      final serviceR = ReporteService();
      final reporteInfo = await serviceR.buscarPorMotivo(context, widget.motivo);

      if (!mounted) return;
      setState(() {
        reporteInfo.sort();
        reportesInfo = reporteInfo;
        _actualizarFiltro(_filtroController.text);
      });
      Navigator.pop(dialogContext);
    } catch (error) {
      print('Error al cargar pallets: $error');
    }
  }

  void _showOptionsMenu(BuildContext context) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(300, 92, 0, 0),
      items: [
        PopupMenuItem(
          value: 1,
          child: Text('Importar Pallet'),
        ),
      ],
    );

    switch (result) {
      default:
        break;
    }
  }

  String fechaCreate = DateFormat('dd/MM/yy').format(DateTime.now());

  Future<List<int>> mostrarFormularioInventario(
      BuildContext context, String motivo) async {
    final serviceR = ReporteService();
    final _formKey = GlobalKey<FormState>();

    TextEditingController fechaController =
        TextEditingController(text: fechaCreate);
    TextEditingController timController = TextEditingController();
    TextEditingController localOrigenController =
        TextEditingController(text: 'Pacasmayo');
    // Adición de tienda por defecto
    TextEditingController destinoController =
        TextEditingController(text: '352');

    return await showDialog<List<int>>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
              title: Text("Agregar Pallet"),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fechaController,
                      readOnly: true,
                      decoration:
                          InputDecoration(labelText: "Fecha de Registro"),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? "Ingrese la fecha" : null,
                    ),
                    TextFormField(
                      controller: timController,
                      decoration: InputDecoration(
                        labelText: "Código de Pallet",
                        suffixIcon: IconButton(
                          icon: Icon(Icons.qr_code_scanner, color: AppColors.verdeClaro),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BarcodeScannerSimple(),
                              ),
                            );
                            if (result != null) {
                              setDialogState(() {
                                timController.text = result;
                              });
                            }
                          },
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Ingrese el Número de Pallet";
                        }
                        if (int.tryParse(value) == null) {
                          return "El código debe ser numérico";
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: localOrigenController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: "Ubicación"),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? "Ingrese el local" : null,
                    ),
                    TextFormField(
                      controller: destinoController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: "Tienda"),
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
                    if (_formKey.currentState?.validate() ?? false) {
                      final nuevoTim = int.tryParse(timController.text);
                      if (nuevoTim == null) return;

                      final existeTim =
                          reportesInfo.any((reporte) => reporte == nuevoTim);

                      if (existeTim) {
                        AwesomeDialog(
                          context: context,
                          dialogType: DialogType.warning,
                          headerAnimationLoop: false,
                          title: 'TIM duplicado',
                          desc:
                              'Ya existe un pallet con el número: $nuevoTim.\nPor favor, ingrese otro número.',
                          btnOkText: 'Aceptar',
                          btnOkOnPress: () {},
                        ).show();
                      } else {
                        final nombreResult = await _userRepo.getNombreUsuario();
                        final nombre = (nombreResult == null || nombreResult.isEmpty) 
                            ? "Usuario" 
                            : nombreResult;

                        // No existe, se puede insertar
                        final reporteTim = ReporteTim(
                          fechaEnvio: fechaController.text,
                          placa: 'Inventario',
                          tim: nuevoTim,
                          localDestino: destinoController.text,
                          localOrigen: localOrigenController.text,
                          creadoPor: nombre,
                          motivo: motivo,
                        );
                        
                        final success = await serviceR.crearReporte(context, reporteTim);
                        if (success) {
                          Navigator.pop(context); // Cierra modal
                          _cargarTims(); // Recarga lista
                        }
                      }
                    }
                  },
                  child: Text("Guardar"),
                ),
              ],
            );
          },
        );
      },
    ) ?? [];
  }

  void _actualizarFiltro(String value) {
    setState(() {
      _reportesFiltrados = value.isEmpty
          ? reportesInfo
          : reportesInfo.where((r) => r.toString().contains(value)).toList();
    });
  }

  // =========================
  // FLUJO DE ELIMINACIÓN
  // =========================

  Future<void> _ejecutarEliminacion(int tim) async {
    final loader = loading.instance;
    loader.showLoadingDialog(context, 'Eliminando Pallet');

    try {
      final serviceR = ReporteService();
      final success = await serviceR.eliminarTim(context, tim);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cierra loading
      }

      if (success) {
        _cargarTims();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pallet $tim eliminado exitosamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<bool> _confirmarEliminacionInicial(int tim) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmación'),
            content: Text('¿Está seguro de eliminar el pallet $tim?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmarEliminacionFinal(int tim) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmación final'),
            content: Text(
              'Va a eliminar el PALLET $tim.\n\nEsta acción no se puede deshacer.\nPresione Confirmar para continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pallets', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => mostrarFormularioInventario(context, widget.motivo),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _filtroController,
              decoration: InputDecoration(
                labelText: 'Buscar Pallet',
                hintText: 'Ingrese código o escanee QR',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(
                    _filtroController.text.isEmpty
                        ? Icons.qr_code_scanner
                        : Icons.close,
                    color: _filtroController.text.isEmpty
                        ? AppColors.verdeClaro
                        : Colors.red,
                  ),
                  onPressed: () async {
                    if (_filtroController.text.isEmpty) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BarcodeScannerSimple(),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _filtroController.text = result;
                          _actualizarFiltro(result);
                        });
                      }
                    } else {
                      setState(() {
                        _filtroController.clear();
                        _actualizarFiltro("");
                      });
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                _actualizarFiltro(value);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'TIP: Mantén presionado un pallet para eliminarlo.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _cargarTims();
                },
                child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: List.generate(_reportesFiltrados.length, (index) {
                  final reporte = _reportesFiltrados[index];
                  return CustomGridCard(
                      icon: Icon(Icons.data_usage,
                          size: 40, color: AppColors.verdeClaro),
                      title: 'PALLET  ${reporte}',
                      onLongPress: (context) async {
                        final confirmar1 = await _confirmarEliminacionInicial(reporte);
                        if (!confirmar1) return;

                        final confirmar2 = await _confirmarEliminacionFinal(reporte);
                        if (!confirmar2) return;

                        _ejecutarEliminacion(reporte);
                      },
                      onTap: (context) async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PalletDetalleScreen(selectedPallet: reporte),
                          ),
                        );
                        if (result == true) {
                          _cargarTims();
                        }
                      });
                }),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
