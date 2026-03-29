import 'package:flutter/material.dart';

const Map<String, String> categoryImageByTitle = {
  'Heavy Household Chores': 'lib/screens/heavy household chores.png',
  'Home Maintenance & Support': 'lib/screens/home maintenance.png',
  'Errands and Logistics': 'lib/screens/errands and logistics.png',
};

const Map<String, String> serviceImageByName = {
  'LPG Gas Tank Replacement': 'lib/screens/lpg gas tank replacement.png',
  'Grocery Collection': 'lib/screens/grocery cpllection.png',
  'Garden Maintenance': 'lib/screens/garden maintenance.png',
  'Utility Assistance': 'lib/screens/utility assistance.png',
  'Water Container Refill': 'lib/screens/water container refill.png',
  'Medical Prescription Pickup': 'lib/screens/medical prescription pickup.png',
};

String? categoryImagePath(String categoryTitle) {
  return categoryImageByTitle[categoryTitle];
}

String? serviceImagePath(String serviceName) {
  return serviceImageByName[serviceName];
}

Widget buildMappedImage(
  String? assetPath, {
  required double height,
  double? width,
  BoxFit fit = BoxFit.cover,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
}) {
  if (assetPath == null || assetPath.isEmpty) {
    return _buildImageFallback(height: height, width: width, borderRadius: borderRadius);
  }

  return SizedBox(
    height: height,
    width: width,
    child: ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback(
            height: height,
            width: width,
            borderRadius: borderRadius,
          );
        },
      ),
    ),
  );
}

Widget _buildImageFallback({
  required double height,
  double? width,
  required BorderRadius borderRadius,
}) {
  return Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: borderRadius,
    ),
    child: const Center(
      child: Icon(Icons.image, color: Colors.grey),
    ),
  );
}
