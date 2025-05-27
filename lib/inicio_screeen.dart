import 'package:control_verde/controller/files/files_controller.dart';
import 'package:control_verde/model/reporteTim_model.dart';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/screens/donaciones/donaciones_screen.dart';
import 'package:control_verde/screens/inventario/inventario.dart';
import 'package:control_verde/screens/recepcion/recepcion.dart';

import 'package:control_verde/utils/alerts.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/widgets/cardInicio.dart';
import 'package:flutter/material.dart';

import 'package:awesome_dialog/awesome_dialog.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({Key? key}) : super(key: key);

  _deleteProductos(BuildContext context) async {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      title: 'Eliminar Productos',
      desc: '¿Estás seguro de que deseas eliminar todos los productos?',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await DatabaseHelper.instance.deleteProfundidad();
        Alerts.instance.showSuccessDialog(
            context, 'Todos los productos han sido eliminados.');
      },
    ).show();
  }

  void _handleAction(BuildContext context, bool hasProductos) {
    if (hasProductos) {
      _deleteProductos(context);
    } else {
      FilesController.instance.handleFileSelection(context,2);
    }
  }

  Widget _buildActionIcon(BuildContext context) {
    return FutureBuilder<bool>(
      future: DatabaseHelper.instance.hasProductos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: AppColors.white),
            ),
          );
        }

        final hasProductos = snapshot.data ?? false;

        return IconButton(
          icon: Icon(hasProductos ? Icons.delete : Icons.upload_file),
          onPressed: () => _handleAction(context, hasProductos),
        );
      },
    );
  }

  Future<List<int>> mostrarFormularioDonacion(
      BuildContext context, String motivo) async {
    final dbHelper = DatabaseHelper.instance;
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

                      await dbHelper.insertReporteTim(reporteTim);

                      final tims = await dbHelper.getTimsByMotivo(motivo);
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
    List<int> tims = await DatabaseHelper.instance.getTimsByMotivo(motivo);

    if (tims.isEmpty) {
      final nuevosTims = await mostrarFormularioDonacion(context, motivo);

      if (nuevosTims.isNotEmpty) {
        final int firstTim = nuevosTims.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductListScreen(selectedTim: firstTim),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ No se creó la donación')),
        );
      }
    } else {
      // Existe al menos uno, redirigir a la ventana del primero
      final int firstTim = tims.first;

      // Asumiendo que la ruta se llama '/detalleReporte' y pasas el TIM como argumento
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductListScreen(selectedTim: firstTim),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Módulos', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        actions: [
          _buildActionIcon(context),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: <Widget>[
            CustomGridCard(
              icon: Icon(Icons.list_alt,
                  size: 40, color: AppColors.verdeClaro),
              title: 'Recepción',
              onTap: (context) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecepcionScreen(),
                ),
              ),
            ),
            CustomGridCard(
              icon: Icon(Icons.stacked_line_chart,
                  size: 40, color: AppColors.verdeClaro),
              title: 'Inventario',
              onTap: (context) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InventarioScreen(),
                ),
              ),
            ),
            CustomGridCard(
                icon: Icon(Icons.handshake,
                    size: 40, color: AppColors.verdeClaro),
                title: 'Donaciones',
                onTap: (context) => _existsTimByMotivo(context, motivo: 'D')),
          ],
        ),
      ),
    );
  }
}
