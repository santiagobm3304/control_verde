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
    showAwesomeDialog(
      context,
      type: DialogType.warning,
      title: 'Advertencia',
      desc: message,
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