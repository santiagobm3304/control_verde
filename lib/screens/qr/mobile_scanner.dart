import 'package:control_verde/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';

class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerSimple> createState() => _BarcodeScannerSimpleState();
}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple> {
  late MobileScannerController _scannerController;
  final AudioPlayer _player = AudioPlayer();

  bool _hasScanned = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();

    _scannerController = MobileScannerController(torchEnabled: false);

    _player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.notification,
          audioFocus: AndroidAudioFocus.none, // 👈 clave
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
      ),
    );
  }

  Future<void> _playBeep() async {
    await _player.play(AssetSource('audio/beep.mp3'));
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _player.dispose();
    super.dispose();
  }

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
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          /// 📷 Cámara
          MobileScanner(
            controller: _scannerController,
            onDetect: (barcodeCapture) async {
              if (_hasScanned) return;

              final value =
                  barcodeCapture.barcodes.map((b) => b.displayValue).join(', ');

              if (value.isNotEmpty) {
                _hasScanned = true;

                await _playBeep();
                HapticFeedback.mediumImpact();

                if (context.mounted) {
                  Navigator.pop(context, value);
                }
              }
            },
          ),

          /// 🎯 Overlay visual
          const _ScannerOverlay(),

          /// Texto guía
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Alinea el código dentro del recuadro",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ),
          ),

          /// 🔦 Botón linterna flotante (abajo derecha)
          Positioned(
            bottom: 24,
            right: 24,
            child: GestureDetector(
              onTap: () {
                _scannerController.toggleTorch();
                HapticFeedback.lightImpact();
                setState(() {
                  _torchEnabled = !_torchEnabled;
                });
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _torchEnabled
                      ? Colors.yellow.shade600
                      : Colors.black.withOpacity(0.6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _torchEnabled ? Icons.flash_on : Icons.flash_off,
                  color: _torchEnabled ? Colors.black : Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎯 Overlay con recuadro central responsive
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        double clamp(double v, double min, double max) => v.clamp(min, max);

        final scanWidth = clamp(width * 0.75, 250, 500);
        final scanHeight = clamp(height * 0.25, 120, 220);

        return Stack(
          children: [
            /// Fondo oscuro
            Container(color: Colors.black.withOpacity(0.6)),

            /// Recuadro central
            Center(
              child: Container(
                width: scanWidth,
                height: scanHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.yellow.shade300,
                    width: 3,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
