import 'dart:typed_data';
import 'package:flutter/material.dart';

class AlbumArtImage extends StatelessWidget {
  final Uint8List? albumArt;
  final double size;
  final IconData fallbackIcon;

  const AlbumArtImage({
    super.key,
    this.albumArt,
    this.size = 50.0,
    this.fallbackIcon = Icons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (albumArt != null)
          ? Image.memory(
              albumArt!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(fallbackIcon, size: size);
              },
            )
          : Icon(fallbackIcon, size: size),
    );
  }
}
