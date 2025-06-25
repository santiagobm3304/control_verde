import 'dart:async';

import 'package:flutter/material.dart';

class loading {
  static final loading instance = loading._init();
  loading._init();

  Future<BuildContext> showLoadingDialog(
      BuildContext context, String fileName) async {
    final completer = Completer<BuildContext>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        if (!completer.isCompleted) {
          completer.complete(dialogContext);
        }
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
                  '$fileName',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Por favor, espera mientras procesamos los datos.',
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

    return completer.future;
  }
}
