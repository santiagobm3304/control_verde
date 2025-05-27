import 'package:control_verde/screens/inventario/inventario_pallets.dart';
import 'package:control_verde/screens/inventario/inventario_producto.dart';

import 'package:control_verde/utils/app_colors.dart';
import 'package:control_verde/widgets/cardInicio.dart';

import 'package:flutter/material.dart';

class InventarioScreen extends StatelessWidget {
  const InventarioScreen({Key? key}) : super(key: key);

  // void _showOptionsMenu(BuildContext context) async {
  //   final result = await showMenu(
  //     context: context,
  //     position: RelativeRect.fromLTRB(300, 92, 0, 0),
  //     items: [
  //       PopupMenuItem(
  //         value: 1,
  //         child: Text('Exportar Inventario'),
  //       ),
  //       PopupMenuItem(
  //         value: 2,
  //         child: Text('Importar Inventario'),
  //       ),
  //     ],
  //   );

  //   switch (result) {
  //     case 1:
  //       //exportar
  //       break;
  //     case 2:
  //       //importar
  //       break;
  //   }
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            const Text('Inventario', style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.verdeClaro,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.more_vert),
        //     onPressed: () => _showOptionsMenu(context),
        //   ),
        // ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: <Widget>[
            CustomGridCard(
              icon:
                  Icon(Icons.data_usage, size: 40, color: AppColors.verdeClaro),
              title: 'Pallets',
              onTap: (context) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PalletsInventarioScreen(motivo: 'I'),
                            ),
                          ),
            ),
            CustomGridCard(
              icon: Icon(Icons.search_rounded,
                  size: 40, color: AppColors.verdeClaro),
              title: 'Ubicar Producto',
              onTap:  (context) => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  InventarioProducto(motivo: 'I'),
                            ),
                          ),
            ),
          ],
        ),
      ),
    );
  }

}
