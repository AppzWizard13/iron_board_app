import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double elevation;
  final Color? shadowColor;

  const GlassmorphicCard({
    required this.child,
    this.elevation = 12,
    this.shadowColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color effectiveShadowColor =
        shadowColor ?? Colors.black12.withOpacity(0.3);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: effectiveShadowColor,
            blurRadius: elevation,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: child,
    );
  }
}
