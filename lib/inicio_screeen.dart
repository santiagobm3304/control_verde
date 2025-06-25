import 'package:control_verde/controller/files/files_controller.dart';
import 'package:control_verde/model/reporteTim_model.dart';

import 'package:control_verde/screens/donaciones/donaciones_screen.dart';
import 'package:control_verde/screens/inventario/inventario.dart';
import 'package:control_verde/screens/recepcion/recepcion.dart';
import 'package:control_verde/services/reporte_service.dart';
import 'package:control_verde/services/socket_service.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/widgets/cardInicio.dart';
import 'package:flutter/material.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({Key? key}) : super(key: key);

  @override
  _InicioScreenState createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  @override
  void initState() {
    super.initState();
    SocketService().init(); // Aquí se inicializa el socket correctamente
  }

  Future<List<int>> mostrarFormularioDonacion(
      BuildContext context, String motivo) async {
    final serviceR = ReporteService();
    final _formKey = GlobalKey<FormState>();

    TextEditingController fechaController = TextEditingController();
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
                      decoration: InputDecoration(labelText: "Fecha de Envío"),
                      validator: (value) =>
                          value!.isEmpty ? "Ingrese la fecha" : null,
                    ),
                    TextFormField(
                      controller: timController,
                      decoration: InputDecoration(labelText: "Código Donación"),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value!.isEmpty ? "Ingrese el TIM" : null,
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
                    if (_formKey.currentState!.validate()) {
                      final reporteTim = ReporteTim(
                        fechaEnvio: fechaController.text,
                        placa: 'Donación',
                        tim: int.parse(timController.text),
                        localDestino: destinoController.text,
                        localOrigen: localOrigenController.text,
                        motivo: motivo,
                      );

                      await serviceR.crearReporte(reporteTim);
                      final tims = await serviceR.buscarPorMotivo(motivo);
                      Navigator.pop(context, tims);
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
    List<int> tims = await serviceR.buscarPorMotivo(motivo);
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ No se creó la donación')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Módulos', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: <Widget>[
            CustomGridCard(
              icon: Icon(Icons.list_alt, size: 40, color: AppColors.verdeClaro),
              title: 'Recepción',
              onTap: (context) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecepcionScreen(),
                ),
              ),
            ),
            CustomGridCard(
              icon:
                  Icon(Icons.handshake, size: 40, color: AppColors.verdeClaro),
              title: 'Donaciones',
              onTap: (context) => _existsTimByMotivo(context, motivo: 'D'),
            ),
            // CustomGridCard(
            //   icon: Icon(Icons.stacked_line_chart,
            //       size: 40, color: AppColors.verdeClaro),
            //   title: 'Inventario',
            //   onTap: (context) => Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //       builder: (context) => InventarioScreen(),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
