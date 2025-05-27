import 'package:control_verde/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';



class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({Key? key}) : super(key: key);

  @override
  _BarcodeScannerSimpleState createState() => _BarcodeScannerSimpleState();

}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple> {
  String? scannedData;
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.verdeClaro,
        title: const Text(
          "Escanear Código de Barras",
          style: TextStyle(color: AppColors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (BarcodeCapture barcode) async {
                if (!_hasScanned) {
                  final value =
                      barcode.barcodes.map((b) => b.displayValue).join(', ');
                  if (value.isNotEmpty) {
                    setState(() {
                      scannedData = value;
                      _hasScanned = true;
                    });
                    Navigator.pop(context, scannedData);
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(scannedData ?? "No se ha escaneado ningún código"),
          ),
          // ElevatedButton(
          //   onPressed: () {
          //     if (scannedData != null) {
          //       Navigator.pop(
          //           context, scannedData); // Retorna el código escaneado
          //     }
          //   },
          //   child: const Text("Guardar y Regresar"),
          // ),
        ],
      ),
    );
  }
}
