import 'dart:io';
import 'package:flutter/material.dart';

class AlbumArtImage extends StatelessWidget {
  final String imagePath;
  final double size;

  final IconData fallbackIcon;

  const AlbumArtImage({
    super.key,
    required this.imagePath,
    this.size = 50.0, // Default size for the leading image
    this.fallbackIcon = Icons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    // First, check if the path points to an actual file on the device.
    if (File(imagePath).existsSync()) {
      // If it's a file, display it using FileImage.
      return ClipRRect(
        borderRadius: BorderRadius.circular(8), // Add nice rounded corners
        child: Image.file(
          File(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // If the file is corrupt or not an image, show the icon.
          errorBuilder: (context, error, stackTrace) {
            return Icon(fallbackIcon, size: size);
          },
        ),
      );
    }
    // Second, if it's not a file, assume it's a bundled asset.
    else if (imagePath.startsWith('assets/images/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // If the asset path is wrong, show the icon.
          errorBuilder: (context, error, stackTrace) {
            return Icon(fallbackIcon, size: size);
          },
        ),
      );
    }
    // Finally, if the path is invalid or empty, just show the icon.
    else {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, size: size),
      );
    }
  }
}