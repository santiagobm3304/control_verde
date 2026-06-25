import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';

class Alerts {
  static final Alerts instance = Alerts._init();
  Alerts._init();

  void showSuccessDialog(BuildContext context, String message) {
    showAwesomeDialog(
      context,
      type: DialogType.success,
      title: 'Éxito',
      desc: message,
    );
  }

  void showErrorDialog(BuildContext context, String message) {
    showAwesomeDialog(
      context,
      type: DialogType.error,
      title: 'Error',
      desc: message,
    );
  }

  void showWarningDialog(BuildContext context, String message) {
    print('📢 Llamando a showWarningDialog con mensaje: $message');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Advertencia'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void showAwesomeDialog(
    BuildContext context, {
    required DialogType type,
    required String title,
    required String desc,
  }) {
    AwesomeDialog(
      context: context,
      dialogType: type,
      title: title,
      desc: desc,
      btnOkOnPress: () {},
    ).show();
  }
}