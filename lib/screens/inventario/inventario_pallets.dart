

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:control_verde/controller/files/files_controller.dart';
import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/screens/inventario/detalle_pallets.dart';

import 'package:control_verde/utils/app_colors.dart';
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
  int? _filtroTim;
  List<int> _reportesFiltrados = [];

  @override
  void initState() {
    super.initState();
    _cargarTims();
  }

  Future<void> _cargarTims() async {
    try {
      final reporteInfo =
          await DatabaseHelper.instance.getTimsByMotivo(widget.motivo);

      setState(() {
        reporteInfo.sort();
        reportesInfo = reporteInfo;
        _reportesFiltrados = reportesInfo;
      });
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
      case 1:
        final result = await FilesController.instance.handleFileSelection(context, 3, reportesInfo: reportesInfo);
        if (result == true) {
              _cargarTims();
        } 
        break;
      default:
        break;
    }
  }


  String fechaCreate = DateFormat('dd/MM/yy').format(DateTime.now());

  Future<List<int>> mostrarFormularioInventario(
      BuildContext context, String motivo) async {
    final dbHelper = DatabaseHelper.instance;
    final _formKey = GlobalKey<FormState>();

    TextEditingController fechaController =
        TextEditingController(text: fechaCreate);
    TextEditingController timController = TextEditingController();
    TextEditingController localOrigenController =
        TextEditingController(text: 'Pacasmayo');

    return await showDialog<List<int>>(
          context: context,
          builder: (context) {
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
                          value!.isEmpty ? "Ingrese la fecha" : null,
                    ),
                    TextFormField(
                      controller: timController,
                      decoration:
                          InputDecoration(labelText: "Código de Pallet"),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value!.isEmpty ? "Ingrese el Número de Pallet" : null,
                    ),
                    TextFormField(
                      controller: localOrigenController,
                      readOnly: true,
                      decoration: InputDecoration(labelText: "Ubicación"),
                      validator: (value) =>
                          value!.isEmpty ? "Ingrese el local" : null,
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
                      final nuevoTim = int.tryParse(timController.text);
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
                        // No existe, se puede insertar
                        final reporteTim = ReporteTim(
                          fechaEnvio: fechaController.text,
                          placa: 'Inventario',
                          tim: nuevoTim!,
                          localDestino: 'Inventario',
                          localOrigen: localOrigenController.text,
                          motivo: motivo,
                        );
                            await dbHelper.insertReporteTim(reporteTim);
                        _cargarTims();
                        Navigator.pop(context, reportesInfo);
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
            onPressed: () => mostrarFormularioInventario(context, 'I'),
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
            DropdownButton<int>(
              value: _filtroTim,
              hint: const Text('Filtrar Pallet'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('Todos los Pallets'),
                ),
                ...reportesInfo.map((reporte) {
                  return DropdownMenuItem<int>(
                    value: reporte,
                    child: Text('Pallet ${reporte}'),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _filtroTim = value;
                  _reportesFiltrados = value == null
                      ? reportesInfo
                      : reportesInfo.where((r) => r == value).toList();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Pallet eliminado exitosamente')),
                          );
                        }
                      });
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
