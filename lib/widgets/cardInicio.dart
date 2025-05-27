import 'package:flutter/material.dart';

class CustomGridCard extends StatelessWidget {
  final Widget? icon;
  final Widget? customIcon;
  final String title;
  final Function(BuildContext) onTap;
  final Function(BuildContext)? onLongPress;

  const CustomGridCard({
    super.key,
    this.icon,
    this.customIcon,
    required this.title,
    required this.onTap,
    this.onLongPress,
  }) : assert(icon != null || customIcon != null,
            'Debe proporcionar icon o customIcon');

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => onTap(context),
        onLongPress: onLongPress != null ? () => onLongPress!(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon ?? icon!,
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
