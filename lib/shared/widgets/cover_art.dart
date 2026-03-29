import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CoverArt extends StatelessWidget {
  final String? url;
  final double size;
  final double borderRadius;

  const CoverArt({super.key, this.url, this.size = 56, this.borderRadius = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => _placeholder(context),
                errorWidget: (_, _, _) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.4,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
