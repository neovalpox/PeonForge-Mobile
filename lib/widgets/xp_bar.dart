import 'package:flutter/material.dart';
import '../theme/wc3_theme.dart';

class XpBar extends StatelessWidget {
  final double progress;
  final String label;

  const XpBar({super.key, required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: WC3Colors.goldDark.withValues(alpha: 0.5), width: 1),
            color: WC3Colors.goldDark.withValues(alpha: 0.15),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [WC3Colors.goldDark, WC3Colors.goldLight]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: WC3Colors.textMid, fontSize: 11)),
      ],
    );
  }
}
