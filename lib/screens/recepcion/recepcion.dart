import 'package:control_verde/controller/files/files_controller.dart';
import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/screens/discrepancias/discrepancias_screen.dart';
import 'package:control_verde/screens/donaciones/donaciones_screen.dart';
import 'package:control_verde/screens/recepcion/recepcion_screen.dart';
import 'package:control_verde/services/reporte_service.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/widgets/cardInicio.dart';

import 'package:flutter/material.dart';

class RecepcionScreen extends StatelessWidget {
  const RecepcionScreen({Key? key}) : super(key: key);

  Future<void> _showDialogSelectedAction(BuildContext context,
      {required String action, required String motivo}) async {
    final service = ReporteService();
    print(motivo);
    List<int> tims = await service.buscarPorMotivo(motivo);
    int? selectedTim;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Selecciona una TIM"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action == 'eliminar'
                      ? "Selecciona la TIM que se finalizará el conteo:"
                      : "Selecciona la TIM en la que vas a trabajar:"),
                  const SizedBox(height: 20),
                  ...tims.map((tim) {
                    return RadioListTile<int>(
                      title: Text("TIM: $tim"),
                      value: tim,
                      groupValue: selectedTim,
                      onChanged: (value) {
                        setState(() => selectedTim = value);
                      },
                    );
                  }).toList(),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedTim != null) {
                      Navigator.pop(context);
                      switch (action) {
                        case 'eliminar':
                          DatabaseHelper.instance.deleteReportes(selectedTim!);
                          break;

                        case 'trabajar':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductosReporteScreen(
                                  selectedTim: selectedTim!),
                            ),
                          );
                          break;

                        case 'discrepar':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DiscrepanciasScreen(
                                  selectedTim: selectedTim!),
                            ),
                          );
                          break;
                        default:
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProductListScreen(selectedTim: selectedTim!),
                            ),
                          );
                          break;
                      }
                    }
                  },
                  child: Text("Aceptar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
              icon: Icon(Icons.upload_file,
                  size: 40, color: AppColors.verdeClaro),
              title: 'Subir Reporte TIM',
              onTap: (context) => FilesController.instance.handleFileSelection(
                context,1
              ),
            ),
            CustomGridCard(
                icon: Icon(Icons.list, size: 40, color: AppColors.verdeClaro),
                title: 'Recepción',
                onTap: (context) => _showDialogSelectedAction(context,
                    action: 'trabajar', motivo: 'T')),
            CustomGridCard(
                customIcon: const Text(
                  '≠',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.verdeClaro,
                  ),
                ),
                title: 'Faltantes y Sobrantes',
                onTap: (context) => _showDialogSelectedAction(context,
                    action: 'discrepar', motivo: 'T')),
            CustomGridCard(
              icon: Icon(Icons.task_alt, size: 40, color: AppColors.verdeClaro),
              title: 'Terminar Recepción',
              onTap: (context) => _showDialogSelectedAction(context,
                  action: 'eliminar', motivo: 'T'),
            ),
          ],
        ),
      ),
    );
  }
}
