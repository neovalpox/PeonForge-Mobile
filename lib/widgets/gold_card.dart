import 'package:flutter/material.dart';
import '../theme/wc3_theme.dart';

class GoldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const GoldCard({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: WC3Colors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WC3Colors.goldDark, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
