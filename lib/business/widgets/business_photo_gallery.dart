import 'package:flutter/material.dart';

class BusinessPhotoGallery extends StatelessWidget {
  final List<String> urls;
  const BusinessPhotoGallery({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              urls[index],
              width: 180,
              height: 140,
              fit: BoxFit.cover,
              semanticLabel: 'Business photo ${index + 1}',
              errorBuilder: (_, _, _) => const SizedBox(
                width: 180,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
