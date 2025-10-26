// lib/components/neu_box.dart

import 'package:flutter/material.dart';

class NeuBox extends StatelessWidget {
  final Widget? child;
  const NeuBox({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    // get theme colors
    var colorScheme = Theme.of(context).colorScheme;

    return Container(
      // **THE FIX**: Add alignment property to center the child widget.
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            //darker shadow on the bottom right
            BoxShadow(
              color: Colors.grey.shade500,
              blurRadius: 15,
              offset: const Offset(5, 5),
            ),

            //lighter shadow on the top left
            const BoxShadow(
              color: Colors.white,
              blurRadius: 15,
              offset: Offset(-5, -5),
            ),
          ]),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
