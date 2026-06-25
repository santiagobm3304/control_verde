import 'package:flutter/material.dart';

class TriStateFilter extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const TriStateFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (value == null) {
      color = Colors.grey;
      text = 'Todos';
    } else if (value == true) {
      color = Colors.green;
      text = 'Sí';
    } else {
      color = Colors.red;
      text = 'No';
    }

    return InkWell(
      onTap: () {
        // ciclo: null → true → false → null
        if (value == null) {
          onChanged(true);
        } else if (value == true) {
          onChanged(false);
        } else {
          onChanged(null);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.black87)),
            SizedBox(height: 4),
            Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
