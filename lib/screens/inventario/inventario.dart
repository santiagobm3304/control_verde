import 'dart:math';

import 'package:control_verde/database/database_helper.dart';
import 'package:control_verde/model/reporteTim_model.dart';
import 'package:control_verde/repository/user_repository.dart';
import 'package:control_verde/screens/inventario/inventario_pallets.dart';
import 'package:control_verde/screens/inventario/inventario_perecibles.dart';
import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/utils/loading.dart';
import 'package:control_verde/widgets/cardInicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class InventarioScreen extends StatelessWidget {
  InventarioScreen({Key? key}) : super(key: key);

  final dataBaseH = DatabaseHelper.instance;
  final UserRepository _userRepo = UserRepository();

  // =========================
  // UTILIDADES
  // =========================

  int generarTim() {
    final random = Random();
    return 1000 + random.nextInt(9000); // 4 dígitos
  }

  // =========================
  // FORMULARIO
  // =========================

  Future<List<int>> mostrarFormularioInventario(
    BuildContext context,
    String motivo,
  ) async {
    final formKey = GlobalKey<FormState>();

    final fechaController = TextEditingController(
      text: DateFormat('dd/MM/yy').format(DateTime.now()),
    );

    final timController = TextEditingController(text: generarTim().toString());
    final destinoController = TextEditingController(text: '352');
    final localOrigenController = TextEditingController(text: 'Pacasmayo');

    final tims = await showDialog<List<int>>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Crear Inventario"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FECHA
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
                          lastDate: DateTime(2100),
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

                    // TIM
                    TextFormField(
                      controller: timController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Código Inventario (TIM)",
                      ),
                    ),

                    // TIENDA
                    TextFormField(
                      controller: destinoController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Tienda",
                      ),
                    ),

                    // LOCAL ORIGEN
                    TextFormField(
                      controller: localOrigenController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Local de Origen",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      final nombre = await _userRepo.getNombreUsuario();

                      final reporteTim = ReporteTim(
                        fechaEnvio: fechaController.text,
                        placa: 'INVENTARIO PERECIBLES',
                        tim: int.parse(timController.text),
                        localDestino: destinoController.text,
                        localOrigen: localOrigenController.text,
                        creadoPor: nombre,
                        motivo: motivo,
                      );

                      await dataBaseH.insertReporteTim(reporteTim);

                      final tims = await dataBaseH.getTimsByMotivo(motivo);

                      if (context.mounted) {
                        Navigator.pop(context, tims);
                      }
                    } catch (e, stack) {
                      debugPrint('❌ Error creando inventario: $e');
                      debugPrintStack(stackTrace: stack);

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('❌ Ocurrió un error al crear el inventario'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  child: const Text("Guardar"),
                ),
              ],
            );
          },
        ) ??
        [];

    return tims;
  }

  // =========================
  // FLUJO INVENTARIO
  // =========================

  Future<void> _existsCodigoByMotivo(
    BuildContext context, {
    required String motivo,
  }) async {
    final dialogContext = await loading.instance
        .showLoadingDialog(context, 'Obteniendo Inventario');

    List<int> tims = await dataBaseH.getTimsByMotivo(motivo);
    Navigator.pop(dialogContext);

    if (tims.isEmpty) {
      final nuevosTims = await mostrarFormularioInventario(context, motivo);

      if (nuevosTims.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ No se creó el Inventario')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              InventarioPerecibles(selectedInventario: nuevosTims.first),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              InventarioPerecibles(selectedInventario: tims.first),
        ),
      );
    }
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            const Text('Inventario', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            CustomGridCard(
              icon: const Icon(Icons.kitchen,
                  size: 40, color: AppColors.verdeClaro),
              title: 'Perecibles',
              onTap: (context) => _existsCodigoByMotivo(context, motivo: 'IP'),
            ),
            CustomGridCard(
              icon: const Icon(Icons.inventory_2,
                  size: 40, color: AppColors.verdeClaro),
              title: 'PGC',
              onTap: (context) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const PalletsInventarioScreen(motivo: 'IPGC'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// FORMATTER FECHA dd/mm/yy
// =========================

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');

    if (text.length > 6) {
      text = text.substring(0, 6);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
