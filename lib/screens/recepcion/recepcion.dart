import 'package:control_verde/screens/recepcion/discrepancias/discrepancias_screen.dart';
import 'package:control_verde/screens/recepcion/conteo/recepcion_screen.dart';
import 'package:control_verde/services/reporte_service.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/widgets/cardInicio.dart';

import 'package:flutter/material.dart';

class RecepcionScreen extends StatelessWidget {
  const RecepcionScreen({Key? key}) : super(key: key);

  Future<void> _showDialogSelectedAction(
    BuildContext context, {
    required String action,
    required String motivo,
  }) async {
    int? selectedTim;
    final service = ReporteService();
    final loader = loading.instance;

    bool loadingClosed = false;

    loader.showLoadingDialog(context, 'Cargando TIMS');

    List<int> tims = [];

    try {
      tims = await service.buscarPorMotivo(context, motivo);
      if (!context.mounted) return;
    } catch (e) {
      debugPrint("ERROR: $e");
    } finally {
      if (context.mounted && !loadingClosed) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingClosed = true;
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: const Text("TIMS"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Selecciona la TIM la cuál se va a $action:"),
                  const SizedBox(height: 20),
                  ...tims.map((tim) => RadioListTile<int>(
                        title: Text("TIM: $tim"),
                        value: tim,
                        groupValue: selectedTim,
                        onChanged: (v) => setState(() => selectedTim = v),
                      )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedTim == null) return;

                    Navigator.pop(dialogCtx);

                    if (!context.mounted) return;

                    switch (action) {
                      case 'eliminar':
                        // Modal 1
                        final confirmar1 =
                            await _confirmarEliminacionInicial(context);
                        if (!confirmar1 || !context.mounted) return;

                        // Modal 2
                        final confirmar2 = await _confirmarEliminacionFinal(
                            context, selectedTim!);
                        if (!confirmar2 || !context.mounted) return;

                        // Loading + eliminación
                        loader.showLoadingDialog(context, 'Eliminando TIM');

                        await ReporteService()
                            .eliminarTim(context, selectedTim!);

                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                        break;

                      case 'trabajar':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductosReporteScreen(
                              selectedTim: selectedTim!,
                            ),
                          ),
                        );
                        break;

                      case 'discrepar':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiscrepanciasScreen(
                              selectedTim: selectedTim!,
                            ),
                          ),
                        );
                        break;
                    }
                  },
                  child: const Text("Aceptar"),
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
            // CustomGridCard(
            //   icon: Icon(Icons.upload_file,
            //       size: 40, color: AppColors.verdeClaro),
            //   title: 'Subir Reporte TIM',
            //   onTap: (context) =>
            //       FilesController.instance.handleFileSelection(context, 1),
            // ),
            CustomGridCard(
                icon: Icon(Icons.list, size: 40, color: AppColors.verdeClaro),
                title: 'Conteo',
                onTap: (context) => _showDialogSelectedAction(context,
                    action: 'trabajar', motivo: 'T')),
            // CustomGridCard(
            //     customIcon: const Text(
            //       '≠',
            //       style: TextStyle(
            //         fontSize: 40,
            //         fontWeight: FontWeight.bold,
            //         color: AppColors.verdeClaro,
            //       ),
            //     ),
            //     title: 'Bitácora',
            //     onTap: (context) => _showDialogSelectedAction(context,
            //         action: 'discrepar', motivo: 'T')),
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

  Future<bool> _confirmarEliminacionInicial(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmación'),
            content: const Text('¿Está seguro de eliminar la TIM?'),
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

  Future<bool> _confirmarEliminacionFinal(
    BuildContext context,
    int tim,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmación final'),
            content: Text(
              'Va a eliminar la TIM $tim.\n\nPresione Confirmar para continuar.',
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
}
