// lib/components/album_art_image.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AlbumArtImage extends StatelessWidget {
  final Uint8List? albumArt;
  final double size;

  const AlbumArtImage({
    super.key,
    required this.albumArt,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    if (albumArt != null) {
      return Image.memory(
        albumArt!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true, // Prevents flicker
      );
    }
    // Fallback placeholder
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.music_note,
        color: Theme.of(context).colorScheme.primary,
        size: size * 0.6,
      ),
    );
  }
}
