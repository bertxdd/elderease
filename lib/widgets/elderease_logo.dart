import 'package:flutter/material.dart';

class ElderEaseLogo extends StatelessWidget {
  const ElderEaseLogo({
    super.key,
    this.size = 120,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'elder_icon.png',
        fit: BoxFit.contain,
      ),
    );
  }
}