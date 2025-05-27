import 'package:flutter/material.dart';


class loading {
  static final loading instance = loading._init();
  loading._init();
  
  Future<BuildContext> showLoadingDialog(
      BuildContext context, String fileName) async {
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 15),
                Text(
                  'Procesando: $fileName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Por favor, espera mientras procesamos el archivo.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(Duration(milliseconds: 100));

    return dialogContext!;
  }
}
